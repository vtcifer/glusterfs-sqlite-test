#!/usr/bin/env ruby
# encoding: US-ASCII

require 'sqlite3'
require 'socket'

fd = IO.sysopen("/proc/1/fd/1", "w")
docker_logger = IO.new(fd,"w")
docker_logger.sync = true

hostname = Socket.gethostname

docker_logger.puts("hostname is #{hostname}")
# open DB
begin
  docker_logger.puts("opening db")
  db = SQLite3::Database.new("/hooks/shared.db3")
  docker_logger.puts("db open")
rescue Exception => e
  docker_logger.puts("failed open - #{e}")
  sleep 0.1
  retry
end

# prepare DB
begin
  docker_logger.puts("preparing db")
  db.execute("CREATE TABLE IF NOT EXISTS testtable (host TEXT NOT NULL, hash BLOB, idx INTEGER, dt TEXT NOT NULL, PRIMARY KEY(host));")
  docker_logger.puts("db prepared")
rescue Exception => e
  docker_logger.puts("failed prepare - #{e}")
  sleep 0.1
  retry
end

idx=0
# test loop
while true do
  20.times do
    idx+=1
    # pick a random size between 1kb and 10 kb and generate random bytes
    rnd_size = rand((1*1024)..(10*1024))
    rnd_bytes = Random.new.bytes(rnd_size)

    # encode it for the sqlite blob
    blob = SQLite3::Blob.new(rnd_bytes)

    # insert into the test table based on hostname
    begin
      db.execute("INSERT OR REPLACE INTO testtable(host,hash,idx,dt) VALUES(?,?,?,datetime('now'));", hostname.encode('UTF-8'), blob, idx)
    rescue SQLite3::BusyException
      sleep 0.1
      retry
    rescue SQLite3::IOException
      sleep 0.1
      retry
    end
    sleep 0.2
  end
  begin
    db_integrity_check = db.execute('pragma integrity_check;')
    table_contents = db.execute('select host,dt,idx from testtable order by dt desc;')
  rescue SQLite3::BusyException
    sleep 0.1
    retry
  rescue SQLite3::IOException
    sleep 0.1
    retry
  end
  docker_logger.puts("DB Integrity check:\n#{db_integrity_check}")
  docker_logger.puts("Table contents:\n#{table_contents.map { |arr| arr.join("|")}.join("\n")}")
end
