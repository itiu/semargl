module semargl.scripts.S11ACLRightsHierarhical;

private import tango.io.Stdout;
private import tango.stdc.string;
private import tango.stdc.stringz;
private import tango.stdc.stdio;
private import tango.core.Thread;

private import semargl.Predicates;
private import semargl.RightTypeDef;
private import trioplax.TripleStorage;
private import semargl.script_util;
private import semargl.fact_tools;
private import trioplax.triple;
private import semargl.Log;

public bool calculate(char* user, char* elementId, uint rightType, TripleStorage ts,
		char*[] hierarhical_departments_or_delegates, char[] pp, char* authorizedElementCategory)
{
	bool result = false;

	version(trace)
		if(elementId !is null)
			log.trace("ACLRightsHierarhical document = {}", elementId[0 .. strlen(elementId)]);

	if((RightType.WRITE == rightType) || (RightType.DELETE == rightType))
	{
		version(trace)
			log.trace("если документ в документообороте и мы хотим модифицировать");
		// если документ в документообороте и мы хотим модифицировать
		//		if(isInDocFlow(elementId, ts))
		{
			// то извлечём все права выданные документооборотом
			//						result = iSystem.authorizationComponent.checkRight("DOCFLOW", null, null, "BA", null, orgIds, category, elementId, rightType);
			result = checkRight(user, elementId, rightType, ts, hierarhical_departments_or_delegates, pp,
					authorizedElementCategory);
		}
		version(trace)
			log.trace("result={}", result);

	} else
	{
		version(trace)
		{
			log.trace("документ не документообороте и его не собираются модифицировать");
			log.trace("выдадим все права выданные системой электоронного архива");
		}
		// иначе выдадим все права выданные системой электронного архива
		//					result = iSystem.authorizationComponent.checkRight(null , null, null, "BA", null, orgIds, category, elementId, rightType);
		result = checkRight(user, elementId, rightType, ts, hierarhical_departments_or_delegates, pp,
				authorizedElementCategory);

		version(trace)
			log.trace("result={}", result);
	}

	return result;
}

bool checkRight(char* user, char* elementId, uint rightType, TripleStorage ts,
		char*[] hierarhical_departments_or_delegates, char[] pp, char* authorizedElementCategory)
{

	version(trace)
		log.trace("S11ACLRightsHierarhical.checkRight hierarhical_departments.length = {}, rightType={}",
				hierarhical_departments_or_delegates.length, rightType);

	// найдем все ACL записи для заданных user и elementId 
	version(trace)
		log.trace("найдем все ACL записи для заданных user и elementId");

	version(trace)
		log.trace("checkRight #1 query: pp={}, o1={}, o2={}", pp, getString(user), getString(elementId));

	triple_list_element* iterator1 = cast(triple_list_element*) ts.getTriplesUseIndexS1PPOO(cast(char*) pp, user,
			elementId);

	version(trace)
		print_list_triple(iterator1);

	bool res = lookRightOfIterator(iterator1, rt_symbols + rightType, ts, authorizedElementCategory);
	ts.list_no_longer_required(iterator1);

	version(trace)
		log.trace("result={}", res);

	if(res == true)
	{
		version(trace)
			log.trace("return true");

		return true;
	}

	// проверим на вхождение elementId в вышестоящих узлах орг структуры
	version(trace)
		log.trace("проверим на вхождение elementId в вышестоящих узлах орг структуры");

	for(int i = hierarhical_departments_or_delegates.length - 1; i >= 0; i--)
	{
		version(trace)
			log.trace("	hierarhical_departments_or_delegates[{}]={}", i, getString(
					hierarhical_departments_or_delegates[i]));

		version(trace)
			log.trace("checkRight #2 query: pp={}, o1={}, o2={}", pp,
					getString(hierarhical_departments_or_delegates[i]), getString(elementId));

		triple_list_element* iterator2 = cast(triple_list_element*) ts.getTriplesUseIndexS1PPOO(cast(char*) pp,
				hierarhical_departments_or_delegates[i], elementId);

		version(trace)
			print_list_triple(iterator2);

		res = lookRightOfIterator(iterator2, rt_symbols + rightType, ts, authorizedElementCategory);
		ts.list_no_longer_required(iterator2);

		version(trace)
			log.trace("	result={}", res);

		if(res == true)
			return true;
	}

	return false;
}

bool lookRightOfIterator(triple_list_element* iterator3, char* rightType, TripleStorage ts,
		char* authorizedElementCategory)
{

	while(iterator3 !is null)
	{

		bool category_match = false;
		bool rights_match = false;

		Triple* triple3 = iterator3.triple;

		if(triple3 !is null)
		{
			char* s = cast(char*) triple3.s;
			char* p = cast(char*) triple3.p;

			if(s is null)
			{
				log.trace("Ex! S11ACLRightsHierarhical.lookRightOfIterator, subject is null, p=" ~ fromStringz(p));
				throw new Exception("S11ACLRightsHierarhical.lookRightOfIterator, subject is null, p=" ~ fromStringz(p));
			}

			triple_list_element* category_triples = ts.getTriples(s, CATEGORY.ptr, null);
			triple_list_element* category_triples_FE = category_triples;

			if(category_triples !is null)
			{
				Triple* category_triple = category_triples.triple;
				if(category_triple !is null)
				{
					char* category = cast(char*) category_triple.o;

					//						log.trace("# {} ?= {}", getString(authorizedElementCategory), getString(category));

					if(strcmp(authorizedElementCategory, category) == 0)
					{
						category_match = true;
					}
				}
				ts.list_no_longer_required(category_triples_FE);
			}

			if(category_match && strcmp(p, RIGHTS.ptr) == 0)
			{
				// проверим, есть ли тут требуемуе нами право
				char* triple2_o = cast(char*) triple3.o;

				version(trace)
					log.trace("#5 lookRightInACLRecord o={}", getString(triple2_o));

				bool is_actual = false;
				while(*triple2_o != 0)
				{
					if(*triple2_o == 'd')
					{
						if(!is_actual)
							is_actual = is_subject_actual(s, ts);

						if(is_actual)
						{
							return true;
						} else
						{
							break;
						}
					}

					version(trace)
						log.trace("lookRightOfIterator ('{}' || '{}' == '{}' ?)", *triple2_o, *(triple2_o + 1),
								*rightType);

					if(*triple2_o == *rightType || *(triple2_o + 1) == *rightType)
					{
						if(!is_actual)
							is_actual = is_subject_actual(s, ts);

						if(is_actual)
						{
							return true;
						} else
							break;
					}
					triple2_o++;
				}
			}
		}
		iterator3 = iterator3.next_triple_list_element;
	}

	return false;
}
