require "rails_helper"
require "open3"
require "zlib"

RSpec.describe "config/db_backup.sh" do
  let(:script) { Rails.root.join("config/db_backup.sh").to_s }
  let(:backups) { Pathname(Dir.mktmpdir) }
  let(:bin) { Pathname(Dir.mktmpdir) }
  let(:today) { Time.now.utc.to_date }

  after do
    FileUtils.rm_rf(backups)
    FileUtils.rm_rf(bin)
  end

  def fake_pg_dump(body)
    bin.join("pg_dump").write("#!/usr/bin/env bash\n#{body}\n")
    bin.join("pg_dump").chmod(0o755)
  end

  def run_backup
    env = {
      "PATH" => "#{bin}:#{ENV.fetch('PATH')}",
      "BACKUP_DIR" => backups.to_s,
      "BACKUP_RETENTION_DAYS" => "14",
      "DATABASE_URL" => "postgres://postgres:secret@db:5432/app"
    }
    Open3.capture3(env, "bash", script)
  end

  def backup_file(date)
    backups.join("#{date.iso8601}.sql.gz")
  end

  def age(file, days)
    file.write("old")
    time = (Time.now - days.days).to_time
    File.utime(time, time, file)
  end

  it "writes today's dump compressed, from the connection string, without owners or grants" do
    fake_pg_dump('echo "dump of $*"')

    _out, _err, status = run_backup

    expect(status).to be_success
    expect(Zlib.gunzip(backup_file(today).binread)).to eq("dump of --no-owner --no-acl postgres://postgres:secret@db:5432/app\n")
    expect(backups.children.map { |file| file.basename.to_s }).to eq([ "#{today.iso8601}.sql.gz" ])
  end

  it "keeps the last 14 days and deletes older dumps" do
    fake_pg_dump("echo dump")
    kept = backup_file(today - 13)
    deleted = backup_file(today - 15)
    age(kept, 13)
    age(deleted, 15)

    run_backup

    expect(kept).to exist
    expect(deleted).not_to exist
  end

  it "fails without leaving a partial file or touching older dumps when pg_dump fails" do
    fake_pg_dump("echo partial; exit 1")
    old = backup_file(today - 20)
    age(old, 20)

    _out, err, status = run_backup

    expect(status).not_to be_success
    expect(err).to eq("database backup failed\n")
    expect(backups.children).to eq([ old ])
  end
end
