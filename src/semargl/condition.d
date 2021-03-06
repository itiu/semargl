module semargl.condition;

private import tango.text.json.Json;
private import tango.stdc.stdio;
private import tango.stdc.string;
private import tango.stdc.stringz;

private import Util = tango.text.Util;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import semargl.Log;
private import semargl.Predicates;
private import semargl.fact_tools;
private import semargl.RightTypeDef;
private import semargl.script_util;

alias char[] string;

byte asObject = 0;
byte asArray = 1;
byte asString = 2;

class Element
{
	Element[char[]] pairs;
	Element[] array;
	char[] str;
	char[] id;

	byte type;

	char[] toString()
	{
		if(type == asObject)
		{
			char[] qq;

			foreach(key; pairs.keys)
			{
				qq ~= key ~ " : " ~ pairs[key].toString() ~ "\r";
			}

			return qq;
		}
		if(type == asArray)
		{
			char[] qq;

			foreach(el; array)
			{
				qq ~= el.toString() ~ "\r";
			}
			return qq;
		} else if(type == asString)
			return str;
		else
			return "?";
	}

}

Element json2Element(Json!(char).JsonValue* je, ref bool[char[]] passed_elements, Element oe = null)
{
	if(oe is null)
		oe = new Element;

	if(je.type == 4)
	{
		auto atts = je.toObject.attributes;

		int i = 0;
		foreach(key, value; atts)
		{
			if((key in passed_elements) is null)
			{
				passed_elements[key] = true;
				char[] key_copy = new char[key.length];

				version(trace)
					log.trace("key={}", key);

				key_copy[] = key[];

				oe.pairs[key_copy] = json2Element(value, passed_elements);
			}
		}

		return oe;
	} else if(je.type == 5)
	{

		auto arr = je.toArray;

		oe.array = new Element[arr.length];

		int qq = 0;
		foreach(aa; arr)
		{
			oe.array[qq] = json2Element(aa, passed_elements);
			qq++;
		}
	} else if(je.type == 1)
	{
		oe.type = asString;

		char[] val = je.toString;

		//		char[] val_copy = new char[val.length + 1];
		//		val_copy[0..val.length] = val[];

		//		oe.str = val_copy;
		oe.str = val;
	}

	return oe;
}

void load_mandats(ref Element[] conditions, TripleStorage ts)
{
	log.trace("start load documents[uid=mandat]");
	triple_list_element* iterator = ts.getTriples(null, DOCUMENT_TEMPLATE_ID.ptr, "mandat".ptr);

	int count = 0;

	while(iterator !is null)
	{
		Triple* triple = iterator.triple;
		if(triple !is null)
		{
			char* mandat_subject = cast(char*) triple.s;

			if(!(*(mandat_subject + 0) == 'd' && *(mandat_subject + 1) == 'r' && *(mandat_subject + 5) == '_'))
			{
				try
				{
					triple_list_element* iterator1 = ts.getTriples(mandat_subject, "condition", null);
					if(iterator1 !is null)
					{
						Triple* triple1 = iterator1.triple;
						if(triple !is null)
						{
							char* qq = triple1.o;
							//					log.trace("str0: {}", getString(qq));

							char* ptr = qq;

							while(*ptr == ' ')
								ptr++;

							bool isQuoted = false;

							if(*ptr == '(')
							{
								while(*ptr != 0)
								{
									if(*ptr == '\'')
									{
										if(isQuoted == false)
											isQuoted = true;
										else
											isQuoted = false;
										*ptr = '"';
									}

									if(isQuoted == false)
									{
										if(*ptr == ')')
											*ptr = '}';
										if(*ptr == '(')
											*ptr = '{';
										if(*ptr == '\'')
											*ptr = '"';
									}

									ptr++;
								}
							}

							char[] str = getString(qq);

							//					log.trace("str1: {}", str);

							try
							{
								Json!(char) json;
								json = new Json!(char);

								json.parse(str);

								Element root = new Element;
								bool[char[]] passed_elements;
								json2Element(json.value, passed_elements, root);

								char[] tt = getString(mandat_subject);

								root.id = new char[tt.length];

								root.id[] = tt[];

								if(conditions.length <= count)
									conditions.length = conditions.length + 16;

								conditions[count] = root;

								count++;

								printf("found mandat %s\n", mandat_subject);
								log.trace("found mandat: {}", root.id);

							} catch(Exception ex)
							{

								printf("error:load mandat #1");
								log.trace("error:json: [{}], exception: {}", str, ex.msg);
							}

						}
					}
				} catch(Exception ex)
				{
					log.trace("error:load mandat #2");
				}
			}

		}
		iterator = iterator.next_triple_list_element;
	}
	conditions.length = count;

	log.trace("end load documents[mandat], count = {}", conditions.length);
}

bool calculate_condition(char* user, ref Element mndt, triple_list_element* iterator_facts_of_document,
		char*[] hierarhical_departments_of_user, uint rightType, TripleStorage ts)
{
	string str_user = fromStringz(user);

	version(trace)
		log.trace("calculate_condition, user={}", getString(user));
	//	log.trace("mndt.type={}", mndt.type);
	//	log.trace("mndt.pairs.length={}", mndt.pairs.length);
	//	log.trace("mndt.pairs.keys={}", mndt.pairs.keys);

	//	log.trace("mndt={}, mndt.type={}", mndt, mndt.type);

	if(mndt is null)
		return false;

	bool res = false;

	if(("whom" in mndt.pairs) !is null)
	{
		char[] whom;
		Element _whom = mndt.pairs["whom"];

		if(_whom !is null)
		{
			whom = _whom.str;

			version(trace)
				log.trace("condition: проверим вхождение whom=[{}] в иерархию пользователя ", whom);

			bool is_whom = false;

			// проверим, попадает ли  пользователь под критерий whom (узел на который выданно)
			//	сначала, проверим самого пользователя
			if(strncmp(user, whom.ptr, whom.length) == 0)
			{
				version(trace)
					log.trace("condition: да, пользователь попадает в иерархию whom");
				is_whom = true;
			} else
			{
				foreach(dep_id; hierarhical_departments_of_user)
				{
					if(strncmp(dep_id, whom.ptr, whom.length) == 0)
					{
						version(trace)
							log.trace("condition: да, пользователь попадает в иерархию whom");
						is_whom = true;
						break;
					} else
					{
						version(trace)
							log.trace("condition: нет, dep_id = [{}]", getString(dep_id));
					}
				}
			}

			if(is_whom == false)
			{
				version(trace)
					log.trace("condition: нет, пользователь не попадает в иерархию whom");
				return false;
			}
		}
	}

	if(("condition" in mndt.pairs) !is null)
	{
		Element right = mndt.pairs["right"];

		version(trace)
			log.trace("rigth={}", right);

		bool f_rigth_type = false;

		foreach(ch; right.str)
		{
			if(ch == 'c' && rightType == RightType.CREATE)
			{
				f_rigth_type = true;
				break;
			} else if(ch == 'r' && rightType == RightType.READ)
			{
				f_rigth_type = true;
				break;
			} else if(ch == 'w' && rightType == RightType.WRITE)
			{
				f_rigth_type = true;
				break;
			} else if(ch == 'u' && rightType == RightType.UPDATE)
			{
				f_rigth_type = true;
				break;
			} else if(ch == 'a')
			{
				f_rigth_type = true;
				break;
			}
		}

		if(f_rigth_type == false)
			return false;

		if(("date_from" in mndt.pairs) !is null && ("date_to" in mndt.pairs) !is null)
		{
			Element date_from = mndt.pairs["date_from"];
			Element date_to = mndt.pairs["date_to"];

			if(date_from !is null && date_to !is null)
			{
				if(is_today_in_interval(date_from.str, date_to.str) == false)
				{
					version(trace)
						log.trace("condition: текущая дата не в указанном мандатом интервале [{} - {}]", date_from.str,
								date_to.str);
					return false;
				}
			}
		}

		Element condt = mndt.pairs["condition"];
		if(condt !is null)
		{
			if(condt.type == asString)
			{
				version(trace)
					log.trace("eval ({})", condt.str);

				bool eval_res = eval(condt.str, iterator_facts_of_document, str_user, ts);
				version(trace)
					log.trace("eval:{}, res={}", condt.str, eval_res);
				return eval_res;
			} else if(condt.type == asArray)
			{
				auto arr = condt.array;

				foreach(aa; arr)
				{
					auto qq = aa.pairs["and"];
					if(qq !is null)
					{
						bool res_op_and = false;

						version(trace)
							log.trace("found AND");

						auto atts = qq.pairs;

						// рассчитаем значение для этого блока 
						foreach(key, value; atts)
						{
							char[] val = value.toString;

							version(trace)
								log.trace("key:value: {}:{}", key, val);

							if(key[0] == 'f' && key[1] == ':')
							{
								key = key[2 .. $];
								version(trace)

									log.trace("this is field {}={}", key, val);

								triple_list_element* iterator1 = iterator_facts_of_document;
								while(iterator1 !is null)
								{
									Triple* triple = iterator1.triple;

									if(strncmp(triple.p, key.ptr, key.length) == 0)
									{
										version(trace)
											log.trace("in document {} found key {}, val={}, triple.o={}", getString(triple.s),
													key, val, getString(triple.o));
										if(strncmp(triple.o, val.ptr, val.length) == 0)
										{
											version(trace)
												log.trace("!!!equals");
											res_op_and = true;
										} else
										{
											res_op_and = false;
											break;
										}
									}

									iterator1 = iterator1.next_triple_list_element;
								}

							} else if(key == "doctype" && res_op_and == true)
							{
								// "doctype" = DOCUMENT_TEMPLATE_ID
								version(trace)
									log.trace("{}={}", key, value.toString);

								triple_list_element* iterator1 = iterator_facts_of_document;
								while(iterator1 !is null)
								{
									Triple* triple = iterator1.triple;

									if(strncmp(triple.p, DOCUMENT_TEMPLATE_ID.ptr, DOCUMENT_TEMPLATE_ID.length) == 0)
									{
										version(trace)
											log.trace("in document {} found key {}, val={}, triple.o={}", getString(triple.s),
													key, val, getString(triple.o));
										if(strncmp(triple.o, val.ptr, val.length) == 0)
										{
											version(trace)
												log.trace("!!!equals");
											res_op_and = true;
										} else
										{
											res_op_and = false;
											break;
										}
									}

									iterator1 = iterator1.next_triple_list_element;
								}

							}

						}
						res = res_op_and;
					}

					version(trace)
						log.trace("aa.type[{}]={}", aa.type, aa);
				}
			}
		}
	}

	version(trace)
		log.trace("calculate_condition return res={}", res);

	return res;
}

bool eval(string expr, triple_list_element* data, string user, TripleStorage ts)
{
	if(expr == "true")
		return true;

	expr = Util.trim(expr);

	version(trace)
		log.trace("expr: {}", expr);

	static int findOperand(string s, string op1)
	{
		int parens = 0;
		foreach_reverse(p, c; s)
		{
			char c2 = 0;

			if(p > 0)
				c2 = s[p - 1];

			if((c == op1[1] && c2 == op1[0]) && parens == 0)
				return p - 1;

			else if(c == ')')
				parens++;
			else if(c == '(')
				parens--;
		}
		return -1;
	}

	// [&&]
	// [||]

	int p1 = findOperand(expr, "&&");
	int p2 = findOperand(expr, "||");

	if(p1 >= 0)
		return eval(expr[0 .. p1], data, user, ts) && eval(expr[p1 + 2 .. $], data, user, ts);

	if(p2 >= 0)
		return eval(expr[0 .. p2], data, user, ts) || eval(expr[p2 + 2 .. $], data, user, ts);

	if(expr.length > 2 && expr[0] == '(' && expr[$ - 1] == ')')
		return eval(expr[1 .. $ - 1], data, user, ts);

	// [==] [!=]

	if(data !is null)
	{
		string A, B;

		string[] tokens = Util.split(expr, " ");

		version(trace)
			log.trace("tokens={}", tokens);

		if(tokens.length != 3)
			return false;

		string tA = tokens[0];
		string tB = tokens[2];

		if(tA[0] == '[')
		{
			// это адресация к другому документу
			// считаем документ указанный в конструкции [field1], 
			// где field1 поле текущего документа содержащее id требуемого нам документа

			string[] ttt = Util.split(tA, ".");
			version(trace)
				log.trace("A:ttt={}", ttt);

			if(ttt.length == 2)
			{
				// 1. вытащим имя поля и возьмем его значение
				string docId = getFirstObject(data, ttt[0][1 .. $ - 2]);
				log.trace("A:docId={}", docId);

				if(docId !is null && docId.length > 3)
				{
					if(ttt[1] == "$rights")
					{
						// 2. считаем документ по значению из[2] в: triple_list_element* doc1
						triple_list_element* data_doc1 = ts.getTriplesUseIndexS1PPOO(null, user.ptr, docId.ptr);

						if(data_doc1 !is null)
						{
							A = getFirstObject(data_doc1, "mo/at/acl#rt");
						}
					} else
					{
						// 2. считаем права у документа
						triple_list_element* data_doc1 = ts.getTriples(docId.ptr, null, null);

						if(data_doc1 !is null)
						{
							A = getFirstObject(data_doc1, ttt[1]);
						}
					}
				}
			}
		} else if(tA[0] == '\'' || tA[0] == '"' || tA[0] == '`')
		{
			// это строка
			A = tA[1 .. $ - 1];
		} else if(tA[0] == '$' && tA[1] == 'u' && tA[2] == 's' && tA[3] == 'e' && tA[4] == 'r')
		{
			// это проверяемый пользователь
			A = user;
		} else
		{
			// нужно найти данный предикат tokens[0] в data и взять его значение
			//			log.trace("нужно найти данный предикат tokens[0] в data и взять его значение");
			A = getFirstObject(data, tA);
			if(A !is null)
				log.trace("{} = {}", tA, A);
		}

		if(tB[0] == '[')
		{
			// это адресация к другому документу
			// считаем документ указанный в конструкции [field1], 
			// где field1 поле текущего документа содержащее id требуемого нам документа

			string[] ttt = Util.split(tB, ".");
			version(trace)
				log.trace("B:ttt={}", ttt);

			if(ttt.length == 2)
			{
				// 1. вытащим имя поля и возьмем его значение
				string docId = getFirstObject(data, ttt[0][1 .. $ - 2]);

				// 2. считаем документ по значению из[2] в: triple_list_element* doc1
				if(docId !is null && docId.length > 3)
				{
					if(ttt[1] == "$rights")
					{
						// 2. считаем документ по значению из[2] в: triple_list_element* doc1
						triple_list_element* data_doc1 = ts.getTriplesUseIndexS1PPOO(null, user.ptr, docId.ptr);

						if(data_doc1 !is null)
						{
							B = getFirstObject(data_doc1, "mo/at/acl#rt");
						}
					} else
					{
						// 2. считаем права у документа
						triple_list_element* data_doc1 = ts.getTriples(docId.ptr, null, null);

						if(data_doc1 !is null)
						{
							B = getFirstObject(data_doc1, ttt[1]);
						}
					}
				}

			}
		} else if(tB[0] == '\'' || tB[0] == '"' || tB[0] == '`')
		{
			// это строка
			B = tB[1 .. $ - 1];
		} else if(tB[0] == '$' && tB[1] == 'u' && tB[2] == 's' && tB[3] == 'e' && tB[4] == 'r')
		{
			// это проверяемый пользователь
			B = user;
		} else
		{
			//			log.trace("нужно найти данный предикат tokens[1] в data и взять его значение");
			// нужно найти данный предикат tokens[1] в data и взять его значение
			B = getFirstObject(data, tB);

			if(B !is null)
				log.trace("{} = {}", tB, B);
		}

		//		log.trace ("[A={} tokens[1]={} B={}]", A, tokens[1], B);

		if(tokens[1] == "==")
			return A == B;

		if(tokens[1] == "*=")
		{
			foreach (ch ; B)
			{
				if (Util.contains (A, ch) == false)
					return false;				
			}
			return true;
		}
	}

	version(trace)
		log.trace("return false");
	return false;

}
