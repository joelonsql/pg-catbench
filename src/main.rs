use postgres::{Client, NoTls};
use serde_json::json;
use std::env;
use std::path::Path;
use std::process::{Command, Stdio};
use sysinfo::System;
use indicatif::{ProgressBar, ProgressStyle};
use uuid::Uuid;
use wherr::wherr;
use std::net::TcpListener;

#[wherr]
fn run_benchmarks() -> Result<(), Box<dyn std::error::Error>> {

    let timeit_repo_url = "https://github.com/joelonsql/pg-timeit.git";
    let timeit_repo_path = "pg-timeit";

    // Function to run a command and print it out
    fn run_command(command: &mut Command) -> Result<(), Box<dyn std::error::Error>> {
        println!("Running command: {:?}", command);
        let output = command.stderr(Stdio::piped()).output()?;
        if !output.status.success() {
            eprintln!("Command failed: {}", String::from_utf8_lossy(&output.stderr));
            return Err("Command execution failed".into());
        }
        Ok(())
    }

    // Clone the pg-timeit repository if it doesn't exist,
    // otherwise pull the latest changes.
    if !Path::new(timeit_repo_path).exists() {
        run_command(Command::new("git")
            .args(&["clone", timeit_repo_url, timeit_repo_path]))?;
    } else {
        run_command(Command::new("git")
            .args(&["pull"])
            .current_dir(timeit_repo_path))?;
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

    let system_config_id: Uuid = client.query_one(
        "SELECT catbench.register_system_config($1::jsonb, $2::jsonb)",
        &[&cpu_info, &os_info],
    )?.get(0);

    loop {
        let rows = client.query(
            "SELECT * FROM catbench.next_commit($1)",
            &[&system_config_id]
        )?;

        if rows.is_empty() {
            println!("No more commits to benchmark for this system configuration.");
            break;
        }

        let row = &rows[0];
        let commit_hash: String = row.get("commit_hash");
        let commit_id: i64 = row.get("commit_id");

        println!("Commit Hash: {}", commit_hash);
        println!("Commit ID: {}", commit_id);

        let postgresql_repo_path = "./postgresql_repo";
        if !Path::new(postgresql_repo_path).exists() {
            panic!("PostgreSQL repository path does not exist");
        }

        run_command(Command::new("git")
            .args(&["checkout", &commit_hash])
            .current_dir(postgresql_repo_path))?;

        // Find an unused TCP/IP port above 1024 to use for the PostgreSQL installation
        let listener = TcpListener::bind("127.0.0.1:0")?;
        let port = listener.local_addr()?.port();
        drop(listener);

        let configure_path = format!("/tmp/{}", commit_hash);

        let mut configure_args = vec![
            format!("--prefix={}", configure_path), 
            format!("--with-pgport={}", port),
            "-C".to_string(),
        ];

        // Append "--without-icu" only for macOS
        if cfg!(target_os = "macos") {
            configure_args.push("--without-icu".to_string());
        }

        run_command(Command::new("./configure")
            .args(&configure_args)
            .current_dir(postgresql_repo_path))?;

        run_command(Command::new("make")
            .arg("clean")
            .current_dir(postgresql_repo_path))?;

        run_command(Command::new("make")
            .arg("-j33")
            .current_dir(postgresql_repo_path))?;

        run_command(Command::new("make")
            .arg("install")
            .current_dir(postgresql_repo_path))?;

        let data_dir = format!("/tmp/{}-data", commit_hash);

        run_command(Command::new(format!("{}/bin/initdb", configure_path))
            .args(&["-D", &data_dir]))?;

        run_command(Command::new(format!("{}/bin/pg_ctl", configure_path))
            .args(&["-D", &data_dir, "-l", &format!("/tmp/{}.log", commit_hash), "start"]))?;

        run_command(Command::new("make")
            .args(&["clean", "install"])
            .current_dir(timeit_repo_path)
            .env("PATH", format!("{}/bin:{}", configure_path, env::var("PATH").unwrap_or_default())))?;

        run_command(Command::new(format!("{}/bin/createdb", configure_path))
            .args(&["-p", &port.to_string(), "catbench"]))?;

        println!("Connecting to PostgreSQL instance at port {}", port);
        let mut benchmark_client = Client::connect(
            &format!("host=localhost port={} dbname=catbench", port), NoTls)?;

        println!("CREATE EXTENSION timeit;");
        benchmark_client.execute("CREATE EXTENSION timeit;", &[])?;

        loop {

            let rows = client.query(
                "SELECT * FROM catbench.next_benchmark($1, $2)",
                &[&system_config_id, &commit_id]
            )?;

            if rows.is_empty() {
                println!("No more benchmarks to run for this commit.");
                break;
            }

            let row = &rows[0];
            let run_id: Uuid = row.get("run_id");
            let benchmark_name: String = row.get("benchmark_name");
            let benchmark_id: i64 = row.get("benchmark_id");

            println!("Run ID: {}", run_id);
            println!("Commit Hash: {}", commit_hash);
            println!("Commit ID: {}", commit_id);
            println!("Benchmark Name: {}", benchmark_name);
            println!("Benchmark ID: {}", benchmark_id);

            println!("Starting benchmark...");
            let test_ids: Vec<i64> = client.query(
                "SELECT id FROM catbench.get_benchmark_test_ids($1)",
                &[&benchmark_name],
            )?.iter().map(|row| row.get(0)).collect();

            let total_tests = test_ids.len() * 3;
            let pb = ProgressBar::new(total_tests as u64);
            pb.set_style(
                ProgressStyle::default_bar()
                    .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({eta})")?
                    .progress_chars("#>-")
            );

            for _ in 0..10 {
                client.execute(
                    "SELECT setseed(0)",
                    &[],
                )?;
                for &test_id in &test_ids {
                    let rows = client.query(
                        "SELECT * FROM catbench.generate_test($1)",
                        &[&test_id]
                    )?;

                    if rows.is_empty() {
                        panic!("catbench.generate_test() didn't return any row");
                    }

                    let row = &rows[0];
                    let function_name: String = row.get("function_name");
                    let input_values: Vec<String> = row.get("input_values");

                    let execution_time: f64 = benchmark_client.query_one(
                        "
                        SELECT timeit.f
                        (
                            function_name := $1,
                            input_values := $2,
                            significant_figures := 1,
                            timeout := '10 seconds'::interval,
                            min_time := '10 ms'::interval
                        )
                        ",
                        &[&function_name, &input_values],
                    )?.get(0);

                    client.execute("
                        SELECT catbench.insert_result(
                            test_id := $1,
                            run_id := $2,
                            execution_time := $3
                        )",
                        &[&test_id, &run_id, &execution_time],
                    )?;
                    pb.inc(1);
                }
            }

            pb.finish_with_message("Benchmark completed");

            client.execute(
                "SELECT catbench.mark_run_as_finished($1)",
                &[&run_id],
            )?;

        }

        run_command(Command::new(format!("{}/bin/pg_ctl", configure_path))
            .args(&["-D", &data_dir, "-m", "i", "stop"]))?;

        std::fs::remove_dir_all(&data_dir).expect("Failed to remove data directory");
        std::fs::remove_dir_all(&configure_path).expect("Failed to remove installation directory");
        std::fs::remove_file(format!("/tmp/{}.log", commit_hash)).expect("Failed to remove log file");

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
