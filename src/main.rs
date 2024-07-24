use indicatif::{ProgressBar, ProgressStyle};
use postgres::{Client, NoTls};
use regex::Regex;
use serde_json::json;
use std::env;
use std::fs;
use std::fs::canonicalize;
use std::path::Path;
use std::process::{Command, Stdio};
use std::str::FromStr;
use sysinfo::System;
use uuid::Uuid;
use wherr::wherr;
use sha2::{Sha512, Digest};
use std::fs::File;
use std::io::Read;
use hex;
use chrono::Utc;
use postgres_types::{ToSql, FromSql};

const TEMP_DIR: &str = "./compiled_postgresql_commits";
const TEMP_PORT: u16 = 54321;
const TIMEIT_REPO_URL: &str = "https://github.com/joelonsql/pg-timeit.git";
const TIMEIT_REPO_PATH: &str = "pg-timeit";
const POSTGRESQL_REPO_PATH: &str = "./postgresql_repo";
const MAX_TARGET_RESULT_COUNT: i64 = 10;

#[derive(ToSql, FromSql, Debug)]
#[postgres(name = "measure_type")]
enum MeasureType {
    #[postgres(name = "cycles")]
    Cycles,
    #[postgres(name = "time")]
    Time,
}

/// Compute the SHA-512 hash of a file and return it as a hexadecimal encoded text string.
fn compute_sha512_hex(file_path: &Path) -> Result<String, Box<dyn std::error::Error>> {
    // Open the file in read-only mode.
    let mut file = File::open(file_path)?;

    // Create a Sha512 hasher instance.
    let mut hasher = Sha512::new();

    // Read the file in chunks and update the hasher.
    let mut buffer = [0u8; 1024];
    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    // Finalize the hasher and get the result.
    let hash = hasher.finalize();

    // Convert the hash to a hexadecimal encoded text string.
    let hash_hex = hex::encode(hash);

    Ok(hash_hex)
}

#[wherr]
fn run_benchmarks() -> Result<(), Box<dyn std::error::Error>> {

    stop_previous_runs()?;

    // Function to run a command and print it out
    fn run_command(command: &mut Command) -> Result<(), Box<dyn std::error::Error>> {
        println!("Running command: {:?}", command);
        let output = command.stderr(Stdio::piped()).output()?;
        if !output.status.success() {
            eprintln!(
                "Command failed: {}",
                String::from_utf8_lossy(&output.stderr)
            );
            return Err("Command execution failed".into());
        }
        Ok(())
    }

    fn stop_if_started(commit_hash: &str) -> Result<(), Box<dyn std::error::Error>> {
        let re = Regex::new(r"^[a-f0-9]{40}$")?;
        if !re.is_match(commit_hash) {
            return Err("Invalid commit hash".into());
        }

        if Path::new(TEMP_DIR).exists() {
            let entry_path = Path::new(TEMP_DIR).join(commit_hash);
            if entry_path.exists() && entry_path.is_dir() {
                let data_dir = format!("{}-data", commit_hash);
                let data_path = entry_path.parent().unwrap().join(&data_dir);

                if data_path.exists() {
                    let pid_file = data_path.join("postmaster.pid");
                    if pid_file.exists() {
                        let pg_ctl_result = run_command(
                            Command::new(format!("{}/bin/pg_ctl", entry_path.display()))
                                .args(&[
                                    "-D",
                                    data_path.to_str().unwrap(),
                                    "-m",
                                    "i",
                                    "stop",
                                ]),
                        );
                        if pg_ctl_result.is_err() {
                            if cfg!(debug_assertions) {
                                println!(
                                    "pg_ctl stop failed for {}. It might already be stopped.",
                                    commit_hash
                                );
                            }
                        }
                    }
                }
            }
        }

        Ok(())
    }

    // Stop any existing instances
    fn stop_previous_runs() -> Result<(), Box<dyn std::error::Error>> {
        let re = Regex::new(r"^[a-f0-9]{40}$")?;
        if Path::new(TEMP_DIR).exists() {
            for entry in std::fs::read_dir(TEMP_DIR)? {
                let entry = entry?;
                let entry_path = entry.path();
                if entry.file_type()?.is_dir() {
                    let dir_name = entry.file_name().into_string().unwrap();
                    if re.is_match(&dir_name) {
                        let data_dir = format!("{}-data", dir_name);
                        let data_path = entry_path.parent().unwrap().join(&data_dir);
                        if data_path.exists() {
                            let pid_file = data_path.join("postmaster.pid");
                            if pid_file.exists() {
                                let pg_ctl_result = run_command(
                                    Command::new(format!("{}/bin/pg_ctl", entry_path.display()))
                                        .args(&[
                                            "-D",
                                            data_path.to_str().unwrap(),
                                            "-m",
                                            "i",
                                            "stop",
                                        ]),
                                );
                                if pg_ctl_result.is_err() {
                                    if cfg!(debug_assertions) {
                                        println!(
                                            "pg_ctl stop failed for {}. It might already be stopped.",
                                            dir_name
                                        );
                                    }
                                }
                            }
                            let log_file = format!("{}.log", dir_name);
                            let log_path = entry_path.parent().unwrap().join(&log_file);
                            if log_path.exists() {
                                std::fs::remove_file(log_path)?;
                            }
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn cleanup_commit(commit_hash: &str) -> Result<(), Box<dyn std::error::Error>> {
        stop_if_started(commit_hash)?;
        if Path::new(TEMP_DIR).exists() {
            let entry_path = Path::new(TEMP_DIR).join(commit_hash);
            if entry_path.exists() && entry_path.is_dir() {
                let data_dir = format!("{}-data", commit_hash);
                let data_path = entry_path.parent().unwrap().join(&data_dir);

                if data_path.exists() {
                    std::fs::remove_dir_all(&data_path)?;
                }

                std::fs::remove_dir_all(&entry_path)?;

                let log_file = format!("{}.log", commit_hash);
                let log_path = entry_path.parent().unwrap().join(&log_file);
                if log_path.exists() {
                    std::fs::remove_file(log_path)?;
                }
            }
        }

        Ok(())
    }

    fn start_postgres(commit_hash: &str) -> Result<(), Box<dyn std::error::Error>> {
        stop_previous_runs()?;

        let configure_path = format!("{}/{}", TEMP_DIR, commit_hash);
        let data_dir = format!("{}/{}-data", TEMP_DIR, commit_hash);
    
        run_command(
            Command::new(format!("{}/bin/pg_ctl", configure_path)).args(&[
                "-D",
                &data_dir,
                "-l",
                &format!("{}/{}.log", TEMP_DIR, commit_hash),
                "start",
            ]),
        )?;
    
        Ok(())
    }
    
    fn start_if_not_started(
        commit_hash: &str
    ) -> Result<(), Box<dyn std::error::Error>> {
        let data_dir = format!("{}/{}-data", TEMP_DIR, commit_hash);
        let pid_file_path = Path::new(&data_dir).join("postmaster.pid");

        if pid_file_path.exists() {
            if let Ok(pid_string) = fs::read_to_string(&pid_file_path) {
                if let Some(pid) = pid_string.lines().next() {
                    if let Ok(pid) = pid.parse::<i32>() {
                        let system = System::new_all();
                        if system.process(sysinfo::Pid::from(pid as usize)).is_some() {
                            // The process is running, no need to start it again
                            return Ok(());
                        }
                    }
                }
            }
        }

        // If the PID file does not exist or the process is not running, start the server
        start_postgres(commit_hash)
    }

    fn compile_postgres(
        commit_hash: &str
    ) -> Result<(), Box<dyn std::error::Error>> {

        cleanup_commit(commit_hash)?;

        let configure_path_rel = format!("{}/{}", TEMP_DIR, commit_hash);
        std::fs::create_dir_all(&configure_path_rel)?;
        let configure_path = canonicalize(&configure_path_rel)?
            .display()
            .to_string();

        if !Path::new(POSTGRESQL_REPO_PATH).exists() {
            panic!("PostgreSQL repository path does not exist");
        }

        run_command(
            Command::new("git")
                .args(&["checkout", &commit_hash])
                .current_dir(POSTGRESQL_REPO_PATH),
        )?;

        run_command(
            Command::new("git")
                .args(&["clean", "-fdx", "-e", "config.cache", "-e", "config.status", "-e", "config.log"])
                .current_dir(POSTGRESQL_REPO_PATH),
        )?;

        let mut configure_args = vec![
            format!("--prefix={}", configure_path),
            format!("--with-pgport={}", TEMP_PORT),
            "-C".to_string(),
        ];

        // Append "--without-icu" only for macOS
        if cfg!(target_os = "macos") {
            configure_args.push("--without-icu".to_string());
        }

        run_command(
            Command::new("./configure")
                .args(&configure_args)
                .current_dir(POSTGRESQL_REPO_PATH),
        )?;

        run_command(
            Command::new("make")
                .arg("clean")
                .current_dir(POSTGRESQL_REPO_PATH),
        )?;

        run_command(
            Command::new("make")
                .arg("-j33")
                .current_dir(POSTGRESQL_REPO_PATH),
        )?;

        run_command(
            Command::new("make")
                .arg("install")
                .current_dir(POSTGRESQL_REPO_PATH),
        )?;

        let data_dir = format!("{}/{}-data", TEMP_DIR, commit_hash);

        run_command(
            Command::new(format!("{}/bin/initdb", configure_path)).args(&["-D", &data_dir]),
        )?;

        start_postgres(&commit_hash)?;

        run_command(
            Command::new("make")
                .args(&["clean", "install"])
                .current_dir(TIMEIT_REPO_PATH)
                .env(
                    "PATH",
                    format!(
                        "{}/bin:{}",
                        configure_path,
                        env::var("PATH").unwrap_or_default()
                    ),
                ),
        )?;

        run_command(
            Command::new(format!("{}/bin/createdb", configure_path)).args(&[
                "-p",
                &TEMP_PORT.to_string(),
                "catbench",
            ]),
        )?;

        let mut benchmark_client = Client::connect(
            &format!("host=localhost port={} dbname=catbench", TEMP_PORT),
            NoTls,
        )?;

        benchmark_client.execute("CREATE EXTENSION timeit;", &[])?;

        Ok(())
    }

    // Function to extract the first isolated CPU core from /proc/cmdline
    fn get_first_isolated_cpu() -> Option<i32> {
        if let Ok(cmdline) = fs::read_to_string("/proc/cmdline") {
            if let Some(captures) = Regex::new(r"isolcpus=(\d+)")
                .unwrap()
                .captures(&cmdline)
            {
                if let Some(isolcpus) = captures.get(1) {
                    if let Ok(first_cpu) = i32::from_str(isolcpus.as_str()) {
                        return Some(first_cpu);
                    }
                }
            }
        }
        None
    }

    fn get_executable_hash(client: &mut Client, system_config_id: Uuid, commit_id: i64) -> Result<Option<String>, Box<dyn std::error::Error>>  {
        let row = client.query_one(
            "SELECT catbench.get_executable_hash($1, $2)",
            &[&system_config_id, &commit_id]
        )?;
        Ok(row.get(0))
    }

    let core_id = get_first_isolated_cpu().unwrap_or(-1);
    if core_id != 1 {
        println!("Using CPU core_id: {}", core_id);
    }

    // Create temporary directory if it does not exist
    std::fs::create_dir_all(TEMP_DIR)?;

    // Clone the pg-timeit repository if it doesn't exist,
    // otherwise pull the latest changes.
    if !Path::new(TIMEIT_REPO_PATH).exists() {
        run_command(Command::new("git").args(&["clone", TIMEIT_REPO_URL, TIMEIT_REPO_PATH]))?;
    } else {
        run_command(
            Command::new("git")
                .args(&["pull"])
                .current_dir(TIMEIT_REPO_PATH),
        )?;
    }

    let mut client = Client::connect("host=localhost", NoTls)?;

    let mut sys = System::new_all();
    sys.refresh_all();
    let cpu_info = json!({
        "arch": System::cpu_arch().unwrap_or_else(|| "<unknown>".to_owned()),
        "cores": sys.physical_core_count().unwrap_or(0),
        "vendor_id": sys.cpus()[0].vendor_id(),
        "brand": sys.cpus()[0].brand()
    });
    let os_info = json!({
        "name": System::name().unwrap_or_else(|| "<unknown>".to_owned()),
        "kernel_version": System::kernel_version().unwrap_or_else(|| "<unknown>".to_owned()),
        "os_version": System::os_version().unwrap_or_else(|| "<unknown>".to_owned())
    });

    let system_config_id: Uuid = client
        .query_one(
            "SELECT catbench.register_system_config($1::jsonb, $2::jsonb)",
            &[&cpu_info, &os_info],
        )?
        .get(0);

    loop {
        println!("Starting a new benchmark test cycle...");

        let rows = client.query(
            "SELECT * FROM catbench.get_tests_for_next_cycle($1, $2)",
            &[&system_config_id, &MAX_TARGET_RESULT_COUNT],
        )?;

        if rows.is_empty() {
            println!("No more tests to run for this system configuration.");
            break;
        }

        let num_tests = rows.len();
        let pb = ProgressBar::new(num_tests as u64);
        pb.set_style(
            ProgressStyle::default_bar()
                .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({eta})")
                .unwrap()
                .progress_chars("#>-"),
        );

        for row in &rows {
            let benchmark_id: i64 = row.get("benchmark_id");
            let benchmark_name: String = row.get("benchmark_name");
            let commit_id: i64 = row.get("commit_id");
            let commit_hash: String = row.get("commit_hash");
            let test_id: i64 = row.get("test_id");
            let executable_hash: Option<String> = get_executable_hash(&mut client, system_config_id, commit_id)?;

            if cfg!(debug_assertions) {
                println!("Benchmark Name: {}", benchmark_name);
                println!("Benchmark ID: {}", benchmark_id);
                println!("Commit Hash: {}", commit_hash);
                println!("Commit ID: {}", commit_id);
                println!("Test ID: {}", test_id);
                println!("Executable Hash: {:?}", executable_hash);
            }

            let configure_path = format!("{}/{}", TEMP_DIR, commit_hash);
            let executable_path = Path::new(&configure_path).join("bin/postgres");

            let mut should_compile = true;
            if cfg!(debug_assertions) {
                println!("Checking if we need to compile or if we can reuse existing...");
            }
            if let Some(stored_hash) = executable_hash {
                if Path::new(&configure_path).exists() {
                    if executable_path.exists() {
                        let computed_hash = compute_sha512_hex(&executable_path)?;
                        if computed_hash == stored_hash {
                            should_compile = false;
                            if cfg!(debug_assertions) {
                                println!("Executable hash matches. Proceeding...");
                            }
                            start_if_not_started(&commit_hash)?;
                        } else {
                            if cfg!(debug_assertions) {
                                println!("Executable hash mismatch! Expected {}, found {}", stored_hash, computed_hash);
                            }
                        }
                    } else {
                        if cfg!(debug_assertions) {
                            println!("Executable not found at {}", executable_path.display());
                        }
                    }
                }
            }
            if should_compile {
                compile_postgres(&commit_hash)?;
                if executable_path.exists() {
                    let computed_hash = compute_sha512_hex(&executable_path)?;
                    client.execute(
                        "
                        SELECT catbench.set_executable_hash(
                            system_config_id := $1,
                            commit_id := $2,
                            executable_hash := $3
                        )",
                        &[&system_config_id, &commit_id, &computed_hash],
                    )?;
                } else {
                    panic!("Compiled but executable not found at {}", executable_path.display());
                }
            }

            let mut benchmark_client = Client::connect(
                &format!("host=localhost port={} dbname=catbench", TEMP_PORT),
                NoTls,
            )?;

            if cfg!(debug_assertions) {
                println!("Starting benchmark...");
            }

            let test_rows =
                client.query("SELECT * FROM catbench.generate_test($1)", &[&test_id])?;

            if test_rows.is_empty() {
                panic!("catbench.generate_test() didn't return any row");
            }

            let test_row = &test_rows[0];
            let function_name: String = test_row.get("function_name");
            let input_values: Vec<String> = test_row.get("input_values");

            let measure_type: MeasureType = MeasureType::Time;

            let start_time = Utc::now();

            let measure_result = benchmark_client.query_one(
                "
                    SELECT * FROM timeit.measure
                    (
                        function_name := $1,
                        input_values := $2,
                        r_squared_threshold := 0.99,
                        sample_size := 10,
                        timeout := '100 ms'::interval,
                        measure_type := $3,
                        core_id := $4
                    )
                    ",
                &[&function_name, &input_values, &measure_type, &core_id],
            )?;

            let end_time = Utc::now();

            let x: Vec<f64> = measure_result.get("x");
            let y: Vec<f64> = measure_result.get("y");
            let r_squared: f64 = measure_result.get("r_squared");
            let slope: f64 = measure_result.get("slope");
            let intercept: f64 = measure_result.get("intercept");
            let iterations: i64 = measure_result.get("iterations");

            client.execute(
                "
                SELECT catbench.insert_result(
                    measure_type := $1,
                    x := $2,
                    y := $3,
                    r_squared := $4,
                    slope := $5,
                    intercept := $6,
                    iterations := $7,
                    benchmark_id := $8,
                    system_config_id := $9,
                    commit_id := $10,
                    test_id := $11,
                    benchmark_duration := ($13::timestamptz - $12::timestamptz)
                )",
                &[
                    &measure_type,
                    &x,
                    &y,
                    &r_squared,
                    &slope,
                    &intercept,
                    &iterations,
                    &benchmark_id,
                    &system_config_id,
                    &commit_id,
                    &test_id,
                    &start_time,
                    &end_time,
                ],
            )?;
            pb.inc(1);

        }

        pb.finish_with_message("Benchmark completed");

    }

    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 1 {
        eprintln!("Usage: {}", args[0]);
        std::process::exit(1);
    }

    run_benchmarks().expect("Benchmark failed");
}
