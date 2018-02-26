namespace :mysqldump do
  desc "production の db を dump して、staging に取り込み、サニタイズ して sql にする"
  task :clone_production_db do
    on roles(:db) do
      dump_from_production
      reset_staging_by_sql
      delete_production_sql
      sanitize_private_data if defined? sanitize_private_data
      dump_from_staging
    end
  end

  desc "staging においてある sql をローカルに持ってきて、展開"
  task :get_server_data do
    on roles(:db) do
      get_sql
      reset_development_by_sql
    end
  end

  desc "production の db を dump"
  task :dump_from_production do
    on roles(:db) do
      dump_from database_yml["production"]
    end
  end

  desc "staging の db を dump"
  task :dump_from_staging do
    on roles(:db) do
      dump_from database_yml["staging"]
    end
  end

  desc "最新の dump ファイルを ローカルに取得"
  task :get_sql do
    on roles(:db) do
      latest_dump = capture("ls -1tr mysql_dump* | tail -n 1").chomp
      get latest_dump, latest_dump
    end
  end

  desc "staging の db をアップデート"
  task :reset_staging_by_sql do
    on roles(:db) do
      reset_by_sql_with("staging")
    end
  end

  desc "直下にある sql ファイルで development db をリセット"
  task :reset_development_by_sql do
    reset_development_by_sql
  end

  def database_yml
    database_yml_path = fetch(:mysqldump)[:database_yml_path]
    database_yml = ERB.new(File.open(database_yml_path).read).result
    YAML.load(database_yml)
  end

  def get_dump_path(settings)
    "mysql_dump-#{settings['database']}-#{DateTime.now}.sql"
  end

  def get_mysql_options(settings)
    {
      user: settings['username'],
      host: settings['host'],
      database: settings['database'],
      password: settings['password'],
      dumpsql_name: get_dump_path(settings)
    }
  end

  def mysqldump_path(mysql_options)
    sprintf("mysqldump -u%{user} -p%{password} -h%{host} %{database}", mysql_options)
  end

  def mysql_path(mysql_options)
    sprintf("mysql -u%{user} -p%{password} -h%{host} %{database}", mysql_options)
  end

  def dump_from(settings)
    mysql_options = get_mysql_options(settings)
    dump_command = mysqldump_path(mysql_options)
    if ignore_tables = fetch(:mysqldump, {})[:ignore_tables]
      ignore_tables.each do |ignore_table_name|
        dump_command += sprintf(" --ignore-table=%{database}.#{ignore_table_name}",
          mysql_options)
      end
    end

    dump_command += " --single-transaction" # Run MySQLDump without locking tables
    dump_command += sprintf(" > %{dumpsql_name}", mysql_options)

    execute dump_command
  end

  def reset_by_sql_with(env)
    fail if env == "production"

    settings = database_yml[env]
    mysql_options = get_mysql_options(settings)
    load_command = mysql_path(mysql_options)
    load_command += " < `ls -1tr ~/mysql_dump* | tail -n 1`"

    execute load_command
  end

  def reset_development_by_sql
    system "bundle exec rake db:reset"
    system "bundle exec rails db < `ls -1tr mysql_dump* | tail -n 1`"
  end

  def delete_production_sql
    execute "ls *mysql_dump-* | xargs rm"
  end
end
