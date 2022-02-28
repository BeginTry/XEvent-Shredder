# XEvent-Shredder
TSQL scripts that shred an Extended Events session event file target into a tabular result set.

The output of <a href="https://docs.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-xe-file-target-read-file-transact-sql">sys.fn_xe_file_target_read_file</a> is not particularly easy to read and interpret. Shredding the XML of the <i>event_data</i> column is necessary. But that is a tedious exercise. These scripts attempt to make it easy by dynamically generating a query that returns data for all selected Global Fields (Actions) and all Event Fields for each event in the session.

Blog Post/Further Reading: <a target="_blank" href="https://itsalljustelectrons.blogspot.com/2019/02/shredding-xml-data-from-extended-events.html">Shredding XML Data From Extended Events</a>

<img alt="Dave Mason - SQL Server - Extended Events" src="https://4.bp.blogspot.com/-rBhn94elYFk/XF-01ui2m6I/AAAAAAAAGJs/aZiXNCi30PwsofGwYIyEYyCgQJbh-AWAgCLcBGAs/s1600/itsalljustelectrons.blogspot.com%2B-%2BSQL%2BServer%2B-%2Bfn_xe_file_target_read_file.png"/>

<h2>UPDATE</h2>
I've added script <i>Read XEvent Session Event File Target ~ By Event.sql</i>. Although there are some similarities to <i>Read XEvent Session Event File Target.sql</i>, note the following differences:
<ol>
  <li>Instead of one (potentially) giant query that covers every event in the session, there is one query per session event. The individual queries only include columns for Global Fields (Actions) and Event Fields selected for the specific event. Fewer columns make the result sets easier to interpret. With fewer calls to the XML.value() function, they are faster too.</li>
  <li>Column name aliases include the <i>FieldType</i> ("Global Field" or "Event Field").</li>
  <li>There is a common table expresion <i>XE_TSQL_TypeXref</i>, which replaces the VIEW. I thought this made more sense. But if the VIEW is preferred, it's easy enough to use that instead.</li>
</ol>

The old script tried to put every Event Field into the same query. One problem with this is that Event Field names sometimes overlap with Global Field (Action) names. ("Database Id" is a good example.) Further, when multiple events are defined for a single session, Event Field names from different events can overlap each other. This often resulted in a query with multiple columns using the same alias. All of these issues go away when using a separate query for each session event, along with aliases that include the FieldType.
