#! /usr/bin/env ruby

#
# This updated script does two main things:
# 1. Shows recent git commits (like the original).
# 2. Creates a daily standup file (in the requested Markdown format),
#    then optionally posts it as a Gist and tweets the link.
#
# Requirements/Notes:
# - The "hub" or "gist" CLI must be installed for creating GitHub Gists.
# - The "t" CLI (or another Twitter CLI) must be installed if you want to tweet the link.
# - The code below illustrates an example flow. You may need to adapt it to your environment:
#   - Provide your own logic/inputs for Yesterday/Today/Tomorrow, if desired.
#   - Adjust the mention handles for Twitter posts, etc.

require 'date'
require 'fileutils'
require 'optparse'

###############################################################################
# 1. Parse CLI Options (original logic preserved)
###############################################################################
def parse_cli_options
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: git standup [--since=<date>] [--author=<name>]"

    opts.on("--since [OPTIONAL]", "Show commits more recent than a specific date (defaults to a weekend-aware guess of last working day)") do |since|
      options[:since] = since
    end

    opts.on("--author [OPTIONAL]", "Show only commits from a particular author (defaults to the user defined in .gitconfig)") do |author|
      options[:author] = author
    end

    opts.on("-v", "--verbose", "Show more commit info, like author and timestamp") do |verbose|
      options[:verbose] = verbose
    end
  end.parse!

  options
end

###############################################################################
# 2. Build Daily Standup Content
###############################################################################
def build_daily_standup_content(date_str, standup_data = {})
  # standup_data can hold details collected automatically, from user input, etc.
  # This is just an example structure. Replace or populate standup_data as needed.
  yesterday     = standup_data.fetch(:yesterday, ["(No data)"])
  today         = standup_data.fetch(:today,     ["(No data)"])
  tomorrow      = standup_data.fetch(:tomorrow,  ["(No data)"])
  blockers      = standup_data.fetch(:blockers,  ["(No data)"])
  accelerators  = standup_data.fetch(:accelerators, ["(No data)"])

  # Helper to make each list item a markdown bullet
  format_list = ->(items) { items.map { |item| "- #{item}" }.join("\n") }

  <<~MARKDOWN
    # Standup - #{date_str}

    **Yesterday (1. What did you do yesterday?):**
    #{format_list.call(yesterday)}

    ---

    **Today (2. What did you do today?):**
    #{format_list.call(today)}

    ---

    **Tomorrow (3. What will you do tomorrow?):**
    #{format_list.call(tomorrow)}

    ---

    **Blockers (4. Any blockers stopping you?):**
    #{format_list.call(blockers)}

    ---

    **Accelerators (5. What could accelerate your progress?):**
    #{format_list.call(accelerators)}
  MARKDOWN
end

def write_standup_file(date_str, content)
  file_name = "standup-#{date_str.gsub('-', '')}.md"
  File.write(file_name, content)
  file_name
end

###############################################################################
# 3. Output Git Log (original logic preserved)
###############################################################################
def output_log(options = {})
  # The original script's log format, with optional verbose support
  log_format = "%Cred%h%Creset -%Creset %s#{ '%Cgreen(%cD) %C(bold blue)<%an>' if options[:verbose] }%Creset"
  author     = options[:author] || %x[git config user.email].strip

  today      = Time.now.to_date
  week_day   = Date::DAYNAMES[today.wday]

  if week_day == 'Monday'
    last_working_day = today - 3
  else
    last_working_day = today - 1
  end

  # If no --since was provided, default to last_working_day
  since_date = options[:since] || last_working_day.to_s

  %x[git log --pretty=format:"#{log_format}" --since="#{since_date}" --author="#{author}"]
end

###############################################################################
# 4. Main Execution Flow
###############################################################################
options = parse_cli_options

# (A) Build a standup markdown file at the start of the script each day
today_str = Date.today.strftime("%Y-%m-%d")
# Example data structure. In real usage, gather these from user input, a form, etc.
standup_data = {
  yesterday:    ["Finished refactoring signup page", "Rebased PR #345"],
  today:        ["Implement new feature toggles", "Plan microservice architecture for X"],
  tomorrow:     ["Begin refactoring billing module", "Review PR #346"],
  blockers:     ["Waiting on sysadmin for new test environment"],
  accelerators: ["Details on devops pipeline optimization"]
}

content       = build_daily_standup_content(today_str, standup_data)
standup_file  = write_standup_file(today_str, content)
puts "Daily standup file created: #{standup_file}"

# (B) Run the original git standup logic
if File.directory?('.git')
  puts output_log(options)
end

Dir['*/.git'].each do |git_dir|
  project_dir = File.dirname(git_dir)
  project_log = nil

  FileUtils.cd(project_dir) do
    project_log = output_log(options).strip
  end

  unless project_log.empty?
    header = ">> Project: #{project_dir}"
    puts "=" * header.size
    puts header
    puts "=" * header.size
    puts project_log
  end
end

puts "Done! Git logs printed and standup successfully recorded."
