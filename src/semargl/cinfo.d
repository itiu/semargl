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
	double prev_total_time = 0;
	double sleep_time = 3;
	bool ff = false;

	while(true)
	{
		Thread.sleep(sleep_time);
		auto tm = WallClock.now;

		int delta_count = all_count_messages - prev_count;
		double delta_working_time = total_time - prev_total_time;

		if(delta_count > 0)// || ff == false)
		{
			Stdout.format(layout("{:yyyy-MM-dd HH:mm:ss} * {}, delta_working_time={}, cps={}, time usage={}", tm, all_count_messages, delta_working_time, delta_count / delta_working_time, delta_working_time/sleep_time*100)).newline;
		}

		if(delta_count > 0)
			ff = false;
		else
			ff = true;

		prev_count = all_count_messages;
		prev_total_time = total_time;
	}
}
