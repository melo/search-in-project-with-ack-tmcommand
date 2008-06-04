#!/usr/bin/env ruby -rcgi

# By Henrik Nyh <http://henrik.nyh.se> 2007-06-26
# Free to modify and redistribute with credit.
#
# Updated to use with ack by Pedro Melo <melo@simplicidade.org> 2008-05-26
# Support for TM_SELECTED_FILES by Corey Jewett <ml@syntheticplayground.com> 2008-05-30
#
# **NOTE WELL**: TextMate does not inherit your PATH, so if you this
# command does not find it define the environment variable
# TM_ACK_COMMAND_PATH in your Preferences > Advanced > Shell Variables with
# the full path of your copy of the ack command.
#

%w{ui web_preview escape textmate tm/process}.each { |lib| require "%s/lib/%s" % [ENV['TM_SUPPORT_PATH'], lib] }

ack_cmd=ENV['TM_ACK_COMMAND_PATH'] || ENV['TM_ACK'] || 'ack'
TextMate.require_cmd(ack_cmd)

NAME = "Search in Project with ack"
HEAD  = <<-HTML
  <style type="text/css">
    table { font-size:0.9em; border-collapse:collapse; border-bottom:1px solid #555; }
    h2 { font-size:1.3em; }
    td { vertical-align:top; white-space:nowrap; padding:0.4em 1em; }
    tr td:first-child { text-align:right; padding-right:1.5em; }
    tr.binary { background:#E8AFA8; }
    tr.binary.odd { background:#E0A7A2; }
    tr#empty { border-bottom:1px solid #FFF; }
    tr#empty td { text-align:center; }
    tr.newFile, tr.binary { border-top:1px solid #555; }
    .keyword { font-weight:bold; margin:0 0.1em; }
    .ellipsis { color:#777; margin:0 0.5em; }
  </style>
  <script type="text/javascript">
    function reveal_file(path) {
      const quote = '"';
      const command = "osascript -e ' tell app "+quote+"Finder"+quote+"' " +
                        " -e 'reveal (POSIX file " +quote+path+quote + ")' " +
                        " -e 'activate' " + 
                      " -e 'end' ";
      TextMate.system(command, null);
    }

  function findPos(obj) {
    var curleft = curtop = 0;
    if (obj.offsetParent) {
      curleft = obj.offsetLeft
      curtop = obj.offsetTop
      while (obj = obj.offsetParent) {
        curleft += obj.offsetLeft
        curtop += obj.offsetTop
      }
    }
    return {left: curleft, top: curtop};
  }
  
  function resizeTableToFit() {
    var table = document.getElementsByTagName("table")[0];
    const minWidth = 450, minHeight = 250;

    var pos = findPos(table);
    var tableFitWidth = table.offsetWidth + pos.left * 2;
    var tableFitHeight = table.offsetHeight + pos.top + 50;
    var screenFitWidth = screen.width - 150;
    var screenFitHeight = screen.height - 150;

    var setWidth = tableFitWidth > screenFitWidth ? screenFitWidth : tableFitWidth;
    var setHeight = tableFitHeight > screenFitHeight ? screenFitHeight : tableFitHeight;  
    setWidth = setWidth < minWidth ? minWidth : setWidth;
    setHeight = setHeight < minHeight ? minHeight : setHeight;

    window.resizeTo(setWidth, setHeight);
  }
  
  </script>
HTML

RESIZE_TABLE = <<-HTML
  <script type="text/javascript">
    resizeTableToFit();
  </script>
HTML

def ellipsize_path(path)
  path.sub(/^(.{30})(.{10,})(.{30})$/) { "#$1?#$3" }
end

def escape(string)
  CGI.escapeHTML(string)
end

def bail(message)
  puts <<-HTML
    <h2>#{ message }</h2>
  HTML
  html_footer
  exit
end

directory = ENV['TM_PROJECT_DIRECTORY'] || 
            ( ENV['TM_FILEPATH'] && File.dirname(ENV['TM_FILEPATH']) )

puts html_head(
  :window_title => NAME,
  :page_title   => NAME,
  :sub_title    => directory || "Error",
  :html_head    => HEAD
)

bail("Not in a saved file") unless directory

query = TextMate::UI.request_string(:title => "Search in Project with ack", :prompt => "Find this:", :default => %x{pbpaste -pboard find})
bail("Search aborted") unless query
IO.popen('pbcopy -pboard find', 'w') { |copy| copy.print query }

puts <<-HTML
  <h2>Searching for #{ escape(query) }</h2>
HTML

selected_files=TextMate.selected_files

if selected_files
	command = [ack_cmd, "-H", query, selected_files]
	puts <<-HTML
	  <p><small>Search limited to  #{selected_files.join(' ')}</small></p>
HTML
else
	Dir.chdir(directory)
	command = [ack_cmd, query]
end

puts <<-HTML
  <table>
HTML

# Used to highlight matches
query_re = Regexp.new( Regexp.escape(CGI.escapeHTML(query)), Regexp::IGNORECASE)

last_path = path = i = nil
err = ""
alternate = true
lines = 0

TextMate::Process.run(command, :interactive_input => false) do |line, type|
  case type
  when :err
    err << line
  when :out
    lines = lines + 1
    line.gsub!(/^([^:]+):(\d+):(.*)$/) do

      relative_path, line_number, content = $1, $2, $3.strip
	
      relative_path.sub!(directory + "/", '') if ENV['TM_SELECTED_FILES']

      path = directory + '/' + relative_path
      url = "txmt://open/?url=file://#{path}&line=#{line_number}"
      fname = "%s:%s" % [ellipsize_path(relative_path), line_number];
      fname = ":%s" % [ line_number ] if (path == last_path);
      
      content = escape(content).
                  # Highlight keywords
                  gsub(query_re) { %{<a href="#{url}"><strong class="keyword">#$&</strong></a>} }.
                  # Ellipsize before, between and after keywords
                  gsub(%r{(^[^<]{25}|</strong>[^<]{15})([^<]{20,})([^<]{15}<strong|[^<]{25}$)}) do
                    %{#$1<span class="ellipsis" title="#{escape($2)}">?</span>#$3}
                  end
      <<-HTML

        <tr class="#{ 'odd' unless (alternate = (not alternate)) } #{ 'newFile' if (path != last_path) }">
          <td>
            <a href="#{ url }" title="#{ "%s:%s" % [path, line_number] }">
              #{ fname }
            </a>
          </td>
          <td>#{ content }</td>
        </tr>

      HTML
    end
    puts line
    last_path = path
  end
end

if lines
  # A paragraph inside the table ends up at the top even though it's output
  # at the end. Something of a hack :)
  puts <<-HTML
    <p>#{lines} matching line#{lines==1 ? '' : 's'}:</p>
    #{RESIZE_TABLE}
  HTML
else
  puts <<-HTML
    <tr id="empty"><td colspan="2">No results.</td></tr>
  HTML
end

if $? != 0
  TextMate::UI.alert(:critical, "Search In Project With Ack Error", err)
  TextMate.exit_discard
end

# TODO: see how to detect command not found in ruby and suggest using
# TM_ACK_COMMAND_PATH to solve it

puts <<-HTML
</table>
HTML

html_footer

TextMate.exit_show_html
