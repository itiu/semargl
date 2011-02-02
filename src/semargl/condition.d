module semargl.condition;

private import tango.text.json.Json;
private import tango.stdc.stdio;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import semargl.Log;
private import semargl.Predicates;
private import tango.stdc.string;
private import semargl.fact_tools;

Json!(char).JsonValue*[] conditions;

void load_mandats(TripleStorage ts)
{
	conditions = new Json!(char).JsonValue*[16];
	log.trace("start load documents[mandat]");
	triple_list_element* iterator = ts.getTriples(null, DOCUMENT_TEMPLATE_ID.ptr, "e277410330be4e7a8814185301e3e5bf".ptr);

	int count = 0;
	while(iterator !is null)
	{
		Triple* triple = iterator.triple;
		if(triple !is null)
		{
			char* mandat_subject = cast(char*) triple.s;
			printf("found mandat %s\n", mandat_subject);

			triple_list_element* iterator1 = ts.getTriples(mandat_subject, "condition", null);
			if(iterator1 !is null)
			{
				Triple* triple1 = iterator1.triple;
				if(triple !is null)
				{
					//					printf("condition: %s\n", cast(char*) triple1.o);

					char* qq = triple1.o;

					char* ptr = qq;
					while(*ptr != 0)
					{
						if(*ptr == ')')
							*ptr = '}';
						if(*ptr == '(')
							*ptr = '{';
						if(*ptr == '\'')
							*ptr = '"';
						ptr++;
					}

					try
					{
						Json!(char) json = new Json!(char);
						json.parse(getString(qq));

						conditions[count] = json.value;

						count++;

						if(conditions.length < count)
							conditions.length = conditions.length + 16;

					}
					catch(Exception ex)
					{
						log.trace("invalid json: [{}], exception: {}", qq, ex.msg);

					}

				}
			}

		}
		iterator = iterator.next_triple_list_element;
	}
	conditions.length = count;

	log.trace("end load documents[mandat], count = {}", conditions.length);
}

bool calculate_condition(Json!(char).JsonValue* mndt, triple_list_element* iterator_facts_of_document,
		char*[] hierarhical_departments_of_user)
{
	log.trace("calculate_condition");

	bool res = false;

	char[] whom;
	Json!(char).JsonValue* _whom = mndt.toObject.value("whom");

	if(_whom !is null)
	{
		whom = _whom.toString;

		log.trace("whom={}", whom);

		bool is_whom = false;
		// проверим, попадает ли  пользователь под критерий whom (узел на который выданно)
		foreach(dep_id; hierarhical_departments_of_user)
		{
			if(strncmp(dep_id, whom.ptr, whom.length) == 0)
			{
				log.trace("да, пользователь попадает в иерархию whom");
				is_whom = true;
				break;
			}
		}

		if(is_whom == false)
		{
			log.trace("нет, пользователь не попадает в иерархию whom");
			return false;
		}
	}

	Json!(char).JsonValue* condt = mndt.toObject.value("condition");
	if(condt !is null)
	{

		if(condt.type == 5)
		{
			auto arr = condt.toArray;

			foreach(aa; arr)
			{
				auto qq = aa.toObject.value("and");
				if(qq !is null)
				{
					log.trace("found AND");
					auto atts = qq.toObject.attributes;

					// рассчитаем значение для этого блока 
					foreach(key, value; atts)
					{
						char[] val = value.toString;
						log.trace("json.value.object.att: {}:{}", key, val);

						if(key[0] == 'f' && key[1] == ':')
						{
							key = key[2 .. $];
							log.trace("this is field {}={}", key, val);

							triple_list_element* iterator1 = iterator_facts_of_document;
							while(iterator1 !is null)
							{
								Triple* triple = iterator1.triple;

								if(strncmp(triple.p, key.ptr, key.length) == 0)
								{
									log.trace("in document {} found key {}, val={}, triple.o={}", getString(triple.s), key, getString(
											triple.o));
									if(strncmp(triple.o, val.ptr, val.length) == 0)
									{
										log.trace("!!!equals");
										res = true;
									}
									else
									{
										res = false;
										break;
									}
								}

								iterator1 = iterator1.next_triple_list_element;
							}

						}
						else if(key == "doctype")
						{
							// "doctype" = DOCUMENT_TEMPLATE_ID
							log.trace("{}={}", key, value.toString);

							triple_list_element* iterator1 = iterator_facts_of_document;
							while(iterator1 !is null)
							{
								Triple* triple = iterator1.triple;

								if(strncmp(triple.p, DOCUMENT_TEMPLATE_ID.ptr, DOCUMENT_TEMPLATE_ID.length) == 0)
								{
									log.trace("in document {} found key {}, val={}, triple.o={}", getString(triple.s), key, getString(
											triple.o));
									if(strncmp(triple.o, val.ptr, val.length) == 0)
									{
										log.trace("!!!equals");
										res = true;
									}
									else
									{
										res = false;
										break;
									}
								}

								iterator1 = iterator1.next_triple_list_element;
							}

						}

						// найдем в документе  

					}

				}

				log.trace("aa.type[{}]={}", aa.type, aa);
			}
		}
	}

	return res;
}
