module semargl.cinfo;

private import tango.io.Stdout;
private import tango.core.Thread;
private import tango.time.WallClock;
private import tango.text.locale.Locale;

private import semargl.server;

private Locale layout;

void go()
{
	layout = new Locale;
	
	int prev_count = 0;
	double sleep_time = 3;

	while(true)
	{
		Thread.sleep(sleep_time);
		
		int delta = all_count_messages - prev_count;

		auto tm = WallClock.now;
		
		Stdout.format(layout ("{:yyyy-MM-dd HH:mm:ss} * {}, cps={}", tm, all_count_messages, delta / sleep_time)).newline;

		prev_count = all_count_messages;
	}
}
