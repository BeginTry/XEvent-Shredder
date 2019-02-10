# XEvent-Shredder
TSQL scripts that shred an Extended Events session event file target into a tabular result set.

The output of <a href="https://docs.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-xe-file-target-read-file-transact-sql">sys.fn_xe_file_target_read_file</a> is not particularly easy to read and interpret. Shredding the XML of the <i>event_data</i> column is necessary. But that is a tedious exercise. These scripts attempt to make it easy by dynamically generating a query that returns data for all selected Global Fields (Actions) and all Event Fields for each event in the session.

Blog Post/Further Reading: <a target="_blank" href="https://itsalljustelectrons.blogspot.com/2019/02/shredding-xml-data-from-extended-events.html">Shredding XML Data From Extended Events</a>
