use postgres::{Client, NoTls};
use serde_json::json;
use std::env;
use sysinfo::System;
use indicatif::ProgressBar;
use indicatif::ProgressStyle;
use uuid::Uuid;

fn run_benchmark(benchmark_name: &str) -> Result<(), Box<dyn std::error::Error>> {
    let mut client = Client::connect("host=localhost", NoTls)?;

    client.execute(
        "SELECT setseed(0)",
        &[],
    )?;

    let mut sys = System::new_all();
    sys.refresh_all();
    let cpu_info = json!({
        "arch": System::cpu_arch().unwrap_or_else(|| "<unknown>".to_owned()),
        "cores": sys.physical_core_count().unwrap_or(0),
        "vendor_id": sys.cpus()[0].vendor_id(),
        "brand": sys.cpus()[0].brand(),
        "frequency": sys.cpus()[0].frequency()
    });
    let os_info = json!({
        "name": System::name().unwrap_or_else(|| "<unknown>".to_owned()),
        "kernel_version": System::kernel_version().unwrap_or_else(|| "<unknown>".to_owned()),
        "os_version": System::os_version().unwrap_or_else(|| "<unknown>".to_owned())
    });

    let host_id: Uuid = client.query_one(
        "SELECT catbench.register_host($1::jsonb, $2::jsonb)",
        &[&cpu_info, &os_info],
    )?.get(0);

    let run_id: Uuid = client.query_one(
        "SELECT catbench.new_run($1, $2::uuid)",
        &[&benchmark_name, &host_id],
    )?.get(0);

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

    for _ in 0..3 {
        for &test_id in &test_ids {
            client.execute(
                "CALL catbench.run_test($1, $2)",
                &[&test_id, &run_id],
            )?;
            pb.inc(1);
        }
    }

    pb.finish_with_message("Benchmark completed");

    client.execute(
        "SELECT catbench.mark_run_as_finished($1)",
        &[&run_id],
    )?;

    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <benchmark_name>", args[0]);
        std::process::exit(1);
    }

    let benchmark_name = &args[1];
    if let Err(err) = run_benchmark(benchmark_name) {
        eprintln!("Error running benchmark: {}", err);
        std::process::exit(1);
    }
}
