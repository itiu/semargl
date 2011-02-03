module semargl.condition;

private import tango.text.json.Json;
private import tango.stdc.stdio;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import semargl.Log;
private import semargl.Predicates;
private import tango.stdc.string;
private import semargl.fact_tools;

byte asObject = 0;
byte asArray = 1;
byte asString = 2;

class Element
{
	Element[char[]] pairs;
	Element[] array;
	char[] str;

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
		}
		else if(type == asString)
			return str;
		else
			return "?";
	}

}

Element json2Element(Json!(char).JsonValue* je, Element oe = null)
{
	if(oe is null)
		oe = new Element;

	if(je.type == 4)
	{
		auto atts = je.toObject.attributes;

		foreach(key, value; atts)
		{
			char[] key_copy = new char[key.length];
			key_copy[] = key[];
			oe.pairs[key_copy] = json2Element(value);
		}

		return oe;
	}
	else if(je.type == 5)
	{
		oe.type = asArray;

		auto arr = je.toArray;

		oe.array = new Element[arr.length];

		int qq = 0;
		foreach(aa; arr)
		{
			oe.array[qq] = json2Element(aa);
			qq++;
		}
	}
	else if(je.type == 1)
	{
		oe.type = asString;
		oe.str = je.toString;
	}

	return oe;
}

void load_mandats(ref Element[] conditions, TripleStorage ts)
{
	Json!(char) json;
	json = new Json!(char);

	//	conditions = new Json!(char).JsonValue*[16];

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
						json.parse(getString(qq));

						Element root = new Element;
						json2Element(json.value, root);
						conditions[count] = root;

						//						log.trace("element root: {}", root.toString);

						count++;

						if(conditions.length < count)
							conditions.length = conditions.length + 16;

					}
					catch(Exception ex)
					{
						log.trace("error:json: [{}], exception: {}", qq, ex.msg);

					}

				}
			}

		}
		iterator = iterator.next_triple_list_element;
	}
	conditions.length = count;

	log.trace("end load documents[mandat], count = {}", conditions.length);
}

bool calculate_condition(char* user, ref Element mndt, triple_list_element* iterator_facts_of_document, char*[] hierarhical_departments_of_user)
{
	log.trace("calculate_condition {}", getString(user));
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
	}

	if(("condition" in mndt.pairs) !is null)
	{

		Element condt = mndt.pairs["condition"];
		if(condt !is null)
		{
			if(condt.type == asArray)
			{
				auto arr = condt.array;

				foreach(aa; arr)
				{
					auto qq = aa.pairs["and"];
					if(qq !is null)
					{
						log.trace("found AND");
						auto atts = qq.pairs;

						// рассчитаем значение для этого блока 
						foreach(key, value; atts)
						{
							char[] val = value.toString;
							log.trace("key:value: {}:{}", key, val);

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
	}

	return res;
}
