module semargl.scripts.S01UserIsAdmin;

private import tango.io.Stdout;
private import tango.stdc.stringz;

private import semargl.Predicates;
private import trioplax.TripleStorage;
private import trioplax.triple;
private import semargl.Log;

static private bool[char*] cache;

public bool calculate(char* user, TripleStorage ts, char*[] array_of_targets_of_hierarhical_departments)
{

	//log.trace("!!! l={}", iterator_on_targets_of_hierarhical_departments.length);

	bool* is_admin = null;
	if(is_admin == null)
	{
		if(isAdmin(user, ts))
		{
			cache[user] = true;
			//log.trace("User is admin? {}", true);
			return true;
		}
		else
		{
			for(int i = 0; i < array_of_targets_of_hierarhical_departments.length; i++)
			{
				//log.trace("!!! {}", fromStringz(iterator_on_targets_of_hierarhical_departments[i]));
				if(isAdmin(array_of_targets_of_hierarhical_departments[i], ts))
				{
					cache[user] = true;
					//log.trace("User is admin? {}", false);
					return true;
				}
			}

		}
		cache[user] = false;
		return false;
	}
	//log.trace("User is admin? {}", *is_admin);
	return *is_admin;
}

public bool isAdmin(char* user, TripleStorage ts)
{
	triple_list_element* iterator0 = ts.getTriples(user, IS_ADMIN.ptr, "true");
	ts.list_no_longer_required (iterator0);

	if(iterator0 != null)
		return true;
	else
		return false;
}
