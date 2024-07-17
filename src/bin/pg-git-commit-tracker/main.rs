use postgres::{Client, NoTls};
use regex::Regex;
use std::error::Error;
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};
use git2::Repository;

fn main() -> Result<(), Box<dyn Error>> {
    let repo_url = "https://git.postgresql.org/git/postgresql.git";
    let repo_path = "postgresql_repo";
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
            .args(&["checkout", "-f", "master"])
            .current_dir(repo_path)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .expect("Failed to checkout master branch");

        Command::new("git")
            .args(&["pull"])
            .current_dir(repo_path)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .expect("Failed to pull latest changes");
    }

    // Open the repository using git2
    let repo = Repository::open(repo_path)?;

    // Get the log of changes
    let log_output = Command::new("git")
        .args(&[
            "log",
            "--name-only",
            "--pretty=format:%H %P"
        ])
        .current_dir(repo_path)
        .output()
        .expect("Failed to execute git log command");

    if !log_output.status.success() {
        eprintln!(
            "Failed to get git log: {}",
            String::from_utf8_lossy(&log_output.stderr)
        );
        return Err(Box::from("Failed to get git log"));
    }

    let log_output = String::from_utf8_lossy(&log_output.stdout);
    let mut current_commit = String::new();
    let mut parent_commit = String::new();
    let mut data_to_insert = Vec::new();
    let mut commits_to_insert = Vec::new();

    for line in log_output.lines() {
        let parts: Vec<&str> = line.splitn(2, ' ').collect();
        if parts.len() == 1 && hash_regex.is_match(parts[0]) {
            current_commit = parts[0].to_string();
            parent_commit = String::new();
            commits_to_insert.push((current_commit.clone(), parent_commit.clone()));
        } else if parts.len() == 2 && hash_regex.is_match(parts[0]) {
            current_commit = parts[0].to_string();
            parent_commit = parts[1].to_string();
            commits_to_insert.push((current_commit.clone(), parent_commit.clone()));
        } else if !line.is_empty() && !current_commit.is_empty() {
            // Escape double quotes and backslashes
            let escaped_line = line.replace("\\", "\\\\").replace("\"", "\\\"");
            data_to_insert.push((current_commit.clone(), parent_commit.clone(), escaped_line));
        }
    }

    // Extract commit details using git2
    let mut commit_details = Vec::new();
    let whitespace_regex = Regex::new(r"\s+").unwrap();
    for (commit_hash, parent_hash) in &commits_to_insert {
        let oid = git2::Oid::from_str(commit_hash)?;
        let commit = repo.find_commit(oid)?;
        let summary = commit.message()
        .unwrap_or("")
        .replace("\\", "")
        .replace("\"", "");
        let summary = whitespace_regex.replace_all(&summary, " ").chars()
        .take(80)
        .collect::<String>();

        let commit_time = commit.time().seconds();

        commit_details.push((
            commit_hash.clone(),
            parent_hash.clone(),
            format!("\"{}\"", summary),
            commit_time
        ));
    }

    // Connect to the PostgreSQL database
    let mut client = Client::connect("host=localhost", NoTls)?;

    // Create the temporary tables
    client.batch_execute(
        "
        CREATE TABLE pg_temp.commits
        (
            id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
            commit_hash TEXT NOT NULL,
            parent_hash TEXT,
            summary TEXT,
            commit_time BIGINT,
            PRIMARY KEY (id),
            UNIQUE (commit_hash),
            CHECK (commit_hash ~ '^[0-9a-f]{40}$'),
            CHECK (parent_hash ~ '^[0-9a-f]{40}$')
        );

        CREATE TABLE pg_temp.commit_files
        (
            id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
            commit_hash TEXT NOT NULL,
            file_path TEXT NOT NULL,
            PRIMARY KEY (id),
            CHECK (commit_hash ~ '^[0-9a-f]{40}$')
        );
    ",
    )?;

    // Insert commits into the temporary commits table
    let mut copy_in_commits = client.copy_in("COPY pg_temp.commits (commit_hash, parent_hash, summary, commit_time) FROM stdin WITH CSV NULL ''")?;
    let writer_commits = &mut copy_in_commits;

    for (commit_hash, parent_hash, summary, commit_time) in commit_details {
        writeln!(writer_commits, "{},{},{},{}", commit_hash, parent_hash, summary, commit_time)?;
    }

    copy_in_commits.finish()?;

    // Insert file changes into the temporary commit_files table
    let mut copy_in_files = client.copy_in("COPY pg_temp.commit_files (commit_hash, file_path) FROM stdin WITH CSV NULL ''")?;
    let writer_files = &mut copy_in_files;

    for (commit_hash, _parent_hash, file_path) in data_to_insert {
        writeln!(writer_files, "{},\"{}\"", commit_hash, file_path)?;
    }

    copy_in_files.finish()?;

    // Create indexes and call merge function
    client.batch_execute(
        "
        CREATE INDEX ON pg_temp.commit_files (commit_hash);
        CREATE INDEX ON pg_temp.commit_files (file_path);
        CREATE INDEX ON pg_temp.commits (commit_hash);
        CALL catbench.merge_new_commits();
    ",
    )?;

    Ok(())
}
