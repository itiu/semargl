module semargl.script_util;

private import tango.io.Stdout;
private import tango.text.convert.Integer;
private import tango.stdc.string;
private import tango.stdc.stringz;
private import tango.stdc.time;

private import semargl.Predicates;
private import semargl.RightTypeDef;
private import trioplax.TripleStorage;
private import semargl.fact_tools;
private import semargl.Log;
private import trioplax.triple;

private final ulong m1 = 1;
ulong mtf = 0;

/*
 * возвращает массив субьектов (s) вышестоящих подразделений по отношению к user   
 */
public char*[] getDepartmentTreePathOfUser(char* user, TripleStorage ts)
{
	// получаем путь до корня в дереве подразделений начиная от заданного подразделения
	char*[] result = new char*[16];
	ubyte count_result = 0;

	triple_list_element* iterator0;
	Triple* triple0;

	//	log.trace("getDepartmentTreePath #1 for user={}", getString(user));

	iterator0 = ts.getTriples(user, MEMBER_OF.ptr, null);
	triple_list_element* iterator0_FE = iterator0;

	//print_list_triple(iterator0);

	if(iterator0 !is null)
	{
		triple0 = iterator0.triple;
		char* next_branch = cast(char*) triple0.o;

		if(next_branch !is null)
		{
			//log.trace("getDepartmentTreePath #1 next_branch={}", getString(next_branch));
			result[count_result] = next_branch;
			count_result++;
		}

		while(next_branch !is null)
		{
			triple_list_element* iterator1 = ts.getTriples(null, HAS_PART.ptr, next_branch);
			triple_list_element* iterator1_FE = iterator1;
			next_branch = null;
			if(iterator1 !is null)
			{
				Triple* triple = iterator1.triple;
				char* s = cast(char*) triple.s;
				//log.trace("next_element1={}", getString (s));
				result[count_result] = s;
				count_result++;
				next_branch = s;
				ts.list_no_longer_required(iterator1_FE);
			}

		}
		ts.list_no_longer_required(iterator0_FE);

	}

	//		Stdout.format("getDepartmentTreePath #5 ok").newline;

	result.length = count_result;
	return result;
}

/*	private final ulong m1 = 1;
	ulong mtf = 1;

 * возвращает массив фактов (s) вышестоящих подразделений по отношению к delegate_id   
 */
public Triple*[] getDelegateAssignersTreeArray(char* person_id, TripleStorage ts)
{

	Triple*[] delegates = new Triple*[50];
	uint result_cnt = 0;

	bool put_in_result(Triple* founded_delegate)
	{
		if(mtf & m1)
			log.trace("проверим, есть ли этот делегат <{}><{}>\"{}\" в нашем списке", fromStringz (founded_delegate.s), fromStringz (founded_delegate.p), fromStringz (founded_delegate.o));
		// проверим, есть ли этот делегат в нашем списке
		for(int i = 0; i < delegates.length; i++)
			if(delegates[i] == founded_delegate)
				return false;

		delegates[result_cnt++] = founded_delegate;
		return true;
	}

	getDelegateAssignersForDelegate(person_id, ts, &put_in_result);

	delegates.length = result_cnt;

	return delegates;
}

public void getDelegateAssignersForDelegate(char* delegate_id, TripleStorage ts, bool delegate(Triple* founed_delegate) process_delegate)
{
	triple_list_element* delegates_facts = ts.getTriples(null, DELEGATION_DELEGATE.ptr, delegate_id);
	triple_list_element* delegates_facts_FE = delegates_facts;

	bool f_stop = false;
	
	if(delegates_facts !is null)
	{
		//log.trace("#2 gda");
		while(delegates_facts !is null && !f_stop)
		{
			//log.trace("#3 gda");
			Triple* de_legate = delegates_facts.triple;
			if(de_legate !is null)
			{
				char* subject = cast(char*) de_legate.s;
				triple_list_element* owners_facts = ts.getTriples(subject, DELEGATION_OWNER.ptr, null);
				triple_list_element* owners_facts_FE = owners_facts;

				if(owners_facts !is null)
				{
					while(owners_facts !is null && !f_stop)
					{
						Triple* owner = owners_facts.triple;
						if(owner !is null)
						{
							//log.trace("#4 gda");

							char* object = cast(char*) owner.o;

							//log.trace("delegate = {}, owner = {}", getString(subject), getString(object));

							/*			  strcpy(result_ptr++, ",");
							 strcpy(result_ptr, object);
							 result_ptr += strlen(object);*/
							if (process_delegate(owner) == false)
							{
								f_stop = true;
								break;
							}

							triple_list_element* with_tree_facts = ts.getTriples(subject, DELEGATION_WITH_TREE.ptr, null);
							triple_list_element* with_tree_facts_FE = with_tree_facts;
							{
								while(with_tree_facts !is null && !f_stop)
								{
									Triple* with_tree = with_tree_facts.triple;
									if(with_tree !is null)
									{
										if(strcmp(cast(char*) with_tree, "1") == 0)
											getDelegateAssignersForDelegate(object, ts, process_delegate);
										with_tree_facts = null;
									}
									else
									{
										with_tree_facts = with_tree_facts.next_triple_list_element;
									}
								}
							}
							ts.list_no_longer_required(with_tree_facts_FE);
							owners_facts = null;
						}
						else
						{
							//?							next_owner = *(owners_facts + 1);
							owners_facts = delegates_facts.next_triple_list_element;
							//?cast(uint*) next_owner;
						}
					}
					ts.list_no_longer_required(owners_facts_FE);
				}
			}
			delegates_facts = delegates_facts.next_triple_list_element;
		}
		ts.list_no_longer_required(delegates_facts_FE);
	}
}

public bool is_subject_actual(char* subject, TripleStorage ts)
{
	char* from;
	char* to;

	triple_list_element* from_iter = ts.getTriples(subject, DATE_FROM.ptr, null);
	triple_list_element* from_iter_FE = from_iter;

	// log.trace("#1");

	{
		while(from_iter !is null)
		{
			Triple* el = from_iter.triple;
			if(el !is null)
			{
				from = cast(char*) el.o;
				if(el !is null)
					break;
				else
					from = null;
			}
			from_iter = from_iter.next_triple_list_element;
		}
		ts.list_no_longer_required(from_iter_FE);
	}

	//	log.trace("#10");

	triple_list_element* to_iter = ts.getTriples(subject, DATE_TO.ptr, null);
	triple_list_element* to_iter_FE = to_iter;
	{
		while(to_iter !is null)
		{
			Triple* el = to_iter.triple;
			if(el !is null)
			{
				to = cast(char*) el.o;
				if(el !is null)
					break;
				else
					to = null;
			}
			to_iter = to_iter.next_triple_list_element;
		}
		ts.list_no_longer_required(to_iter_FE);
	}

	//	log.trace("#20");	

	return is_today_in_interval(from, to);
}

public tm* get_local_time()
{
	time_t rawtime;
	tm* timeinfo;

	time(&rawtime);
	timeinfo = localtime(&rawtime);

	return timeinfo;
}

public char[] get_year(tm* timeinfo)
{
	char[] lt = new char[4];
	itoa(lt, cast(uint) timeinfo.tm_year + 1900);
	return lt;
}

public char[] get_month(tm* timeinfo)
{
	char[] lt = new char[2];
	itoa(lt, cast(uint) timeinfo.tm_mon + 1);
	if(timeinfo.tm_mon < 9)
		lt[0] = '0';
	return lt;
}

public char[] get_day(tm* timeinfo)
{
	char[] lt = new char[2];
	itoa(lt, cast(uint) timeinfo.tm_mday);
	if(timeinfo.tm_mday < 10)
		lt[0] = '0';
	return lt;
}

public int cmp_date_with_tm(char* date, tm* timeinfo)
{

	assert(strlen(date) == 10);

	char[] today_y = get_year(timeinfo);
	char[] today_m = get_month(timeinfo);
	char[] today_d = get_day(timeinfo);

	for(int i = 0; i < 4; i++)
	{
		if(*(date + i + 6) > today_y[i])
			return 1;
		else if(*(date + i + 6) < today_y[i])
			return -1;
	}

	for(int i = 0; i < 2; i++)
	{
		if(*(date + i + 3) > today_m[i])
			return 1;
		else if(*(date + i + 3) < today_m[i])
			return -1;
	}

	for(int i = 0; i < 2; i++)
		if(*(date + i) > today_d[i])
			return 1;
		else if(*(date + i) < today_d[i])
			return -1;

	return 0;
}

public bool is_today_in_interval(char* from, char* to)
{
	//log.trace("#itii 11");

	tm* timeinfo = get_local_time();

	if(from !is null && strlen(from) == 10 && cmp_date_with_tm(from, timeinfo) > 0)
		return false;

	//log.trace("#itii 22");

	if(to !is null && strlen(to) == 10 && cmp_date_with_tm(to, timeinfo) < 0)
		return false;

	//log.trace("#itii 33");
	return true;
}

unittest
{

	Stdout.format("\n ::: TESTS START ::: ").newline;

	tm* timeinfo = get_local_time();
	Stdout.format("\nLocal time : {}.{}.{}", get_day(timeinfo), get_month(timeinfo), get_year(timeinfo)).newline;

	timeinfo.tm_year = 45;
	timeinfo.tm_mon = 8;
	timeinfo.tm_mday = 5;

	char[] date = "05.09.1945";

	Stdout.format("\n{} == {}.{}.{}?\n", date, get_day(timeinfo), get_month(timeinfo), get_year(timeinfo)).newline;

	assert(cmp_date_with_tm(date.ptr, timeinfo) == 0);
	assert(!is_today_in_interval("10.10.1990".ptr, "10.10.2000".ptr));
	assert(is_today_in_interval("10.10.1990".ptr, "10.10.2200".ptr));

	Stdout.format(" ::: TESTS FINISH ::: \n").newline;
}
