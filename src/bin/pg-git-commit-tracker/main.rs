use std::process::{Command, Stdio};
use std::path::Path;
use regex::Regex;
use std::error::Error;
use postgres::{Client, NoTls};
use std::io::Write;

fn main() -> Result<(), Box<dyn Error>> {
    let repo_url = "https://git.postgresql.org/git/postgresql.git";
    let repo_path = "postgresql_repo";
    let since_tag = "REL_13_0";
    let until_tag = "HEAD";
    let hash_regex = Regex::new(r"^[0-9a-f]{40}$").unwrap();

    // Clone the repository if it doesn't exist, otherwise pull the latest changes
    if !Path::new(repo_path).exists() {
        Command::new("git")
            .args(&["clone", repo_url, repo_path])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .expect("Failed to clone repository");
    } else {
        Command::new("git")
            .args(&["checkout", "master"])
            .current_dir(repo_path)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .expect("Failed to pull latest changes");

        Command::new("git")
            .args(&["pull"])
            .current_dir(repo_path)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .expect("Failed to pull latest changes");
    }

    // Get the log of changes
    let log_output = Command::new("git")
        .args(&["log", "--name-only", "--pretty=format:%H", &format!("{}..{}", since_tag, until_tag)])
        .current_dir(repo_path)
        .output()
        .expect("Failed to execute git log command");

    if !log_output.status.success() {
        eprintln!("Failed to get git log: {}", String::from_utf8_lossy(&log_output.stderr));
        return Err(Box::from("Failed to get git log"));
    }

    let log_output = String::from_utf8_lossy(&log_output.stdout);
    let mut current_commit = String::new();
    let mut data_to_insert = Vec::new();

    for line in log_output.lines() {
        if hash_regex.is_match(line) {
            current_commit = line.to_string();
        } else if !line.is_empty() {
            // Escape double quotes and backslashes
            let escaped_line = line.replace("\\", "\\\\").replace("\"", "\\\"");
            data_to_insert.push((current_commit.clone(), escaped_line));
        }
    }

    // Connect to the PostgreSQL database
    let mut client = Client::connect("host=localhost", NoTls)?;

    // Create the temporary table
    client.batch_execute("
        CREATE TEMP TABLE pg_temp.commit_files
        (
            id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
            commit_hash TEXT NOT NULL,
            file_path TEXT NOT NULL,
            PRIMARY KEY (id),
            CHECK (commit_hash ~ '^[0-9a-f]{40}$')
        );
    ")?;

    // Copy data to the temporary table
    let mut copy_in = client.copy_in("COPY pg_temp.commit_files (commit_hash, file_path) FROM stdin WITH CSV")?;
    let writer = &mut copy_in;

    for (commit_hash, file_path) in data_to_insert {
        writeln!(writer, "\"{}\",\"{}\"", commit_hash, file_path)?;
    }

    copy_in.finish()?;

    client.batch_execute("
        CREATE INDEX ON pg_temp.commit_files (commit_hash);
        CREATE INDEX ON pg_temp.commit_files (file_path);
        CALL catbench.merge_new_commits();
    ")?;

    Ok(())
}
