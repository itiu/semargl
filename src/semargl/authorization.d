module semargl.authorization;

private import semargl.Predicates;

private import tango.io.Stdout;
private import tango.stdc.string;
private import tango.stdc.stringz;
private import tango.stdc.stdlib;
private import tango.io.stream.Map;
private import Integer = tango.text.convert.Integer;

private import tango.io.device.File;

private import Text = tango.text.Util;
private import tango.time.StopWatch;
private import tango.time.WallClock;
private import tango.time.Clock;
private import tango.io.FileScan;

private import tango.text.locale.Locale;
private import tango.text.convert.TimeStamp;
private import tango.text.convert.Layout;
private import tango.core.Thread;

private import semargl.scripts.S05InDocFlow;
private import semargl.scripts.S01AllLoggedUsersCanCreateDocuments;
private import semargl.scripts.S01UserIsAdmin;
private import semargl.scripts.S09DocumentOfTemplate;
private import semargl.scripts.S10UserIsAuthorOfDocument;
private import semargl.scripts.S11ACLRightsHierarhical;
private import semargl.scripts.DocumentOfTemplateLocalAdmin;

private import semargl.RightTypeDef;
private import semargl.script_util;

private import semargl.persistent_triple_storage;

private import semargl.fact_tools;
private import semargl.Log;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.memory.TripleHashMap;
private import trioplax.memory.TripleStorageMemory;
private import trioplax.mongodb.TripleStorageMongoDB;
private import trioplax.memory.IndexException;

private import semargl.Category;

//private import mom_client;

private import semargl.server;
private import semargl.condition;

private import tango.text.json.Json;

class Authorization
{
	Element[] conditions;

	private final ulong m1 = 1;
	ulong mtf = 0;

	private bool triples_in_memory = false;
	private bool use_cache_for_TripleStorageOnMongodb = false;

	private char[][] i_know_predicates;
	private TripleStorage ts = null;
	private TripleStorageMemory ts_mem = null;
	private TripleStorageMongoDB ts_mongo = null;

	int[] counters;

	private char[] log_path = "";
	private File log_file;
	private bool load_n3log_into_mongodb;

	this(char[][char[]] props, bool _triples_in_memory, bool _use_cache_for_TripleStorageOnMongodb,
			bool _load_n3log_into_mongodb)
	{
		conditions = new Element[256];

		triples_in_memory = _triples_in_memory;
		load_n3log_into_mongodb = _load_n3log_into_mongodb;
		use_cache_for_TripleStorageOnMongodb = _use_cache_for_TripleStorageOnMongodb;

		counters = new int[10];

		i_know_predicates = new char[][21];

		uint d = 0;

		//		 запись о праве, данная часть ACL требует переработки!

		//      - система выдающая право, "BA"/"DOCFLOW"
		i_know_predicates[d++] = AUTHOR_SYSTEM;
		//      - "user"/routeName
		i_know_predicates[d++] = AUTHOR_SUBSYSTEM;
		//		 - id user or id route.
		i_know_predicates[d++] = AUTHOR_SUBSYSTEM_ELEMENT;
		i_know_predicates[d++] = TARGET_SYSTEM; //           - система, для которой выдали права, "BA"/"DOCFLOW".

		i_know_predicates[d++] = TARGET_SUBSYSTEM; //       - "user"/"department".
		i_know_predicates[d++] = TARGET_SUBSYSTEM_ELEMENT; // - user id or department id.

		i_know_predicates[d++] = CATEGORY; // - категория элемента, на который выдаются права (DOCUMENT, DOCUMENTTYPE, DICTIONARY и т. д.).
		i_know_predicates[d++] = DATE_FROM; // - период действия прав (до (с возможностью указания открытых интервалов значение null)).
		i_know_predicates[d++] = DATE_TO; // - период действия прав (от (с возможностью указания открытых интервалов- значение null)).
		i_know_predicates[d++] = ELEMENT_ID; // - идентификатор элемента, на который выдаются права.
		i_know_predicates[d++] = RIGHTS; // - "c|r|u|d"

		//		 запись о делегировании
		i_know_predicates[d++] = DELEGATION_DELEGATE; // - кому делегируют
		i_know_predicates[d++] = DELEGATION_OWNER; // - кто делегирует
		i_know_predicates[d++] = DELEGATION_WITH_TREE; // - делегировать с учетом дерева делегатов

		// document
		i_know_predicates[d++] = CREATOR; // - создатель объекта(документа, типа документа, справочника)
		i_know_predicates[d++] = SUBJECT;
		//		i_know_predicates[d++] = "magnet-ontology#typeName";

		// ORGANIZATION
//		i_know_predicates[d++] = HAS_PART;

		i_know_predicates[d++] = MEMBER_OF;
		i_know_predicates[d++] = IS_ADMIN;

		i_know_predicates[d++] = DOCUMENT_TEMPLATE_ID;
		i_know_predicates[d++] = DELEGATION_DOCUMENT_ID;

		init(props);
	}

	public TripleStorage getTripleStorage()
	{
		return ts;
	}

	private char[] pp = null;

	private int getIntProps(char[] str)
	{
		char[] value = props[str];
		if(value !is null)
		{
			//			value[value.length - 1] = 0;
			return atoi(value.ptr);
		}
		return 0;
	}

	private char[] getStrProps(char[] str)
	{
		char[] value = props[str];
		if(value !is null)
		{
			log.trace("{} = {}", str, value);
			//			value[value.length - 1] = 0;
			return value;
		} else
			return null;
	}

	private void init(char[][char[]] props)
	{
		try
		{
			log.trace("authorization init..");
			Stdout.format("authorization init..").newline;

			if(triples_in_memory)
			{
				ts_mem = new TripleStorageMemory(getIntProps("index_SPO_count"), getIntProps("index_SPO_short_order"),
						getIntProps("index_SPO_key_area"));

				ts_mem.set_new_index(idx_name.S, getIntProps("index_S_count"), getIntProps("index_S_short_order"),
						getIntProps("index_S_key_area"));
				//			ts_mem.set_new_index(idx_name.P, str2int("index_P_count"), str2int("index_P_short_order"), str2int("index_P_key_area"));
				ts_mem.set_new_index(idx_name.O, getIntProps("index_O_count"), getIntProps("index_O_short_order"),
						getIntProps("index_O_key_area"));
				ts_mem.set_new_index(idx_name.PO, getIntProps("index_PO_count"), getIntProps("index_PO_short_order"),
						getIntProps("index_PO_key_area"));
				ts_mem.set_new_index(idx_name.SP, getIntProps("index_SP_count"), getIntProps("index_SP_short_order"),
						getIntProps("index_SP_key_area"));
				ts_mem.set_new_index(idx_name.S1PPOO, getIntProps("index_S1PPOO_count"), getIntProps(
						"index_S1PPOO_short_order"), getIntProps("index_S1PPOO_key_area"));

				ts = ts_mem;
			} else
			{
				ts_mongo = new TripleStorageMongoDB(getStrProps("mongodb_server"), getIntProps("mongodb_port"));

				if(use_cache_for_TripleStorageOnMongodb == true)
					ts_mongo.set_cache();

				ts = cast(TripleStorage) ts_mongo;
			}

			ts.setPredicatesToS1PPOO(TARGET_SUBSYSTEM_ELEMENT, ELEMENT_ID, RIGHTS);
			//			ts.setPredicatesToS1PPOO(AUTHORIZATION_ACL_NAMESPACE, TARGET_SUBSYSTEM_ELEMENT, RIGHTS);

//			ts.define_predicate_as_multiple(HAS_PART);
			ts.set_log_query_mode(false);
			//			ts.f_trace_addTriple = true;

			//		ts.setPredicatesToS1PPOO("magnet-ontology/authorization/acl#targetSubsystemElement", "magnet-ontology/authorization/acl#elementId",
			//				"magnet-ontology/authorization/acl#rights");

			pp = TARGET_SUBSYSTEM_ELEMENT ~ ELEMENT_ID;
			//

			if(triples_in_memory || load_n3log_into_mongodb)
			{
				char[] root = ".";
				log.trace("Scanning '{}'", root);

				auto scan = (new FileScan)(root, ".n3");
				log.trace("\n{} Folders\n", scan.folders.length);
				foreach(folder; scan.folders)
					log.trace("{}\n", folder);
				log.trace("\n{0} Files\n", scan.files.length);

				foreach(file; scan.files)
				{
					log.trace("{}\n", file);
					load_from_file(file, i_know_predicates, ts);
				}
				log.trace("\n{} Errors", scan.errors.length);
				foreach(error; scan.errors)
					log.trace(error);

				scan = (new FileScan)(root, ".n3log");
				log.trace("\n{} Folders\n", scan.folders.length);
				foreach(folder; scan.folders)
					log.trace("{}\n", folder);
				log.trace("\n{0} Files\n", scan.files.length);

				FilePath[] fp = scan.files;

				char[][] fp_str = new char[][fp.length];

				for(int i = 0; i < fp.length; i++)
				{
					fp_str[i] = fp[i].toString();
				}
				fp_str = fp_str.sort;

				for(int i = 0; i < fp_str.length; i++)
				{
					log.trace("{}\n", fp_str[i]);
					load_from_file(new FilePath(fp_str[i]), i_know_predicates, ts);
				}

				log.trace("\n{} Errors", scan.errors.length);
				foreach(error; scan.errors)
					log.trace(error);
			}
			//		print_list_triple(ts.getTriples("record", null, null, false));

			//		ts.removeTriple("record", "magnet-ontology#target", "92e57b6d-83e3-485f-8885-0bade363f759");

			//		print_list_triple(ts.getTriples("record", null, null, false));

			log.trace("authorization init ... ok");
			Stdout.format("authorization init.. ok").newline;

			//			ts.log_query = true;
			ts.print_stat();
		} catch(IndexException ex)
		{
			if(ex.errCode == errorCode.short_order_is_full)
			{
				char[] prop_name = "index_" ~ ex.idxName ~ "_short_order";
				int short_order_param = atoi(props[prop_name].ptr);

				log.trace("prev short order param = {}", short_order_param);
				Stdout.format("prev short order param = {}", short_order_param).newline;
				short_order_param++;
				log.trace("new short order param = {}", short_order_param);
				Stdout.format("prev short order param = {}", short_order_param).newline;
				props[prop_name] = Integer.toString(short_order_param);
			}
			if(ex.errCode == errorCode.block_triple_area_is_full)
			{
				char[] prop_name = "index_" ~ ex.idxName ~ "_key_area";
				int param = atoi(props[prop_name].ptr);

				log.trace("prev key area param = {}", param);
				Stdout.format("prev key area param = {}", param).newline;
				param += 1000 * 1024;
				log.trace("prev key area param = {}", param);
				Stdout.format("prev key area param = {}", param).newline;

				props[prop_name] = Integer.toString(param);
			}

			File props_conduit;
			auto props_path = new FilePath("./semargl.properties");
			props_conduit = new File(props_path.toString(), File.ReadWriteCreate);
			auto output = new MapOutput!(char)(props_conduit.output);

			output.append(props);
			output.flush;
			props_conduit.close;

			log.trace("wait to exit");

			throw ex;
		} catch(Exception ex)
		{
			throw ex;
		}
	}

	public void logginTriple(char command, char[] s, char[] p, char[] o)
	{
		auto layout = new Locale;

		auto tm = WallClock.now;
		auto dt = Clock.toDate(tm);
		char[] tmp1 = new char[35 + s.length + p.length + o.length];
		char[18] tmp;

		auto actual_log_path = layout("data/authorize-data-{:yyyy-MM-dd}.n3log", WallClock.now);
		if(actual_log_path != log_path || log_file is null)
		{

			log_path = actual_log_path;

			if(log_file !is null)
			{
				log_file.close;
			}

			auto style = File.ReadWriteOpen;
			style.share = File.Share.Read;
			style.open = File.Open.Append;
			log_file = new File(log_path, style);
		}

		// так сделано из невозможности задать параметр из двух цифр в Util.layout
		if(command == 'A')
		{
			auto now = Util.layout(tmp1, "%0-%1-%2 %3:%4:%5,%6 A <%7><%8>\"%9\" .\n",
					convert(tmp[0 .. 4], dt.date.year), convert(tmp[6 .. 8], dt.date.month), convert(tmp[4 .. 6],
							dt.date.day), convert(tmp[8 .. 10], dt.time.hours),
					convert(tmp[10 .. 12], dt.time.minutes), convert(tmp[12 .. 14], dt.time.seconds), convert(
							tmp[14 .. 17], dt.time.millis), s, p, o);

			log_file.output.write(now);
		} else if(command == 'U')
		{
			auto now = Util.layout(tmp1, "%0-%1-%2 %3:%4:%5,%6 U <%7><%8>\"%9\" .\n",
					convert(tmp[0 .. 4], dt.date.year), convert(tmp[6 .. 8], dt.date.month), convert(tmp[4 .. 6],
							dt.date.day), convert(tmp[8 .. 10], dt.time.hours),
					convert(tmp[10 .. 12], dt.time.minutes), convert(tmp[12 .. 14], dt.time.seconds), convert(
							tmp[14 .. 17], dt.time.millis), s, p, o);

			log_file.output.write(now);
		} else if(command == 'D')
		{
			auto now = Util.layout(tmp1, "%0-%1-%2 %3:%4:%5,%6 D <%7><%8>\"%9\" .\n",
					convert(tmp[0 .. 4], dt.date.year), convert(tmp[6 .. 8], dt.date.month), convert(tmp[4 .. 6],
							dt.date.day), convert(tmp[8 .. 10], dt.time.hours),
					convert(tmp[10 .. 12], dt.time.minutes), convert(tmp[12 .. 14], dt.time.seconds), convert(
							tmp[14 .. 17], dt.time.millis), s, p, o);

			log_file.output.write(now);
		}
	}

	private char[] convert(char[] tmp, long i)
	{
		return Integer.formatter(tmp, i, 'u', '?', 8);
	}

	version(trace)
	{
		bool f_authorization_trace = true;
	} else
	{
		bool f_authorization_trace = false;
	}

	// необходимые данные загружены, сделаем пробное выполнение скриптов для заданного пользователя
	public bool calculateRightOfAuthorizedElement(char* authorizedElementCategory, char* authorizedElementId,
			char* User, uint targetRightType, char*[] hierarhical_departments_or_delegates, bool isAdmin,
			triple_list_element* iterator_facts_of_document)
	{
		if(f_authorization_trace)
		{
			log.trace("");
			log.trace("autorize start, authorizedElementCategory={}, authorizedElementId={}, User={}", getString(
					authorizedElementCategory), getString(authorizedElementId), getString(User));
		}

		bool calculatedRight;

		if(f_authorization_trace)
			log.trace("autorize:S01UserIsAdmin res={}", isAdmin);

		bool result;
		if(strcmp(authorizedElementCategory, semargl.Category.PERMISSION.ptr) == 0)
		{
			calculatedRight = semargl.scripts.S10UserIsPermissionTargetAuthor.calculate(User, authorizedElementId,
					targetRightType, ts);

			result = isAdmin || calculatedRight;

			if(f_authorization_trace)
				log.trace("return autorize: isAdmin || calculatedRight = {}", result);

			return result;
		}

		result = strcmp(authorizedElementCategory, semargl.Category.DOCUMENT.ptr) == 0 && semargl.scripts.DocumentOfTemplateLocalAdmin.calculate(
				User, authorizedElementId, targetRightType, ts, hierarhical_departments_or_delegates, pp);
		if(result)
		{
			if(f_authorization_trace)
				log.trace("return autorize: DocumentOfTemplateLocalAdmin result = {}", result);

			return true;
		}
		if(f_authorization_trace)
			log.trace("autorize: end DocumentOfTemplateLocalAdmin result = {}", result);

		int is_in_docflow = -1;
		if((targetRightType == RightType.UPDATE || targetRightType == RightType.DELETE || targetRightType == RightType.WRITE) && strcmp(
				authorizedElementCategory, semargl.Category.DOCUMENT.ptr) == 0)
		{
			if(f_authorization_trace)
				log.trace("autorize: category = DOCUMENT");

			is_in_docflow = semargl.scripts.S05InDocFlow.calculate(User, authorizedElementId, targetRightType, ts);
			if(is_in_docflow == 1)
			{
				//counters[1]++;
				if(f_authorization_trace)
					log.trace("return autorize: S05InDocFlow = {}", 1);

				return true;
			} else if(is_in_docflow == 0)
			{
				//counters[2]++;
				if(f_authorization_trace)
					log.trace("return autorize: S05InDocFlow = {}", 0);

				return isAdmin;
			}
		}

		if(f_authorization_trace)
			log.trace("autorize: end S05InDocFlow");

		if(targetRightType == RightType.CREATE && (strcmp(authorizedElementCategory, semargl.Category.DOCUMENT.ptr) == 0 || (*authorizedElementId == '*' && strcmp(
				authorizedElementCategory, semargl.Category.DOCUMENT_TEMPLATE.ptr) == 0)))

		{
			if(semargl.scripts.S01AllLoggedUsersCanCreateDocuments.calculate(targetRightType))
			{
				if(f_authorization_trace)
					log.trace("return autorize: S01AllLoggedUsersCanCreateDocuments = {}", true);

				return true;
			}

			if(f_authorization_trace)
				log.trace("autorize: end S01AllLoggedUsersCanCreateDocuments");
		}

		result = strcmp(authorizedElementCategory, semargl.Category.DOCUMENT.ptr) == 0 && semargl.scripts.S09DocumentOfTemplate.calculate(
				User, authorizedElementId, targetRightType, ts, hierarhical_departments_or_delegates, pp);
		if(result)
		{
			if(f_authorization_trace)
				log.trace("return autorize: S09DocumentOfTemplate result = {}", result);

			return true;
		}
		if(f_authorization_trace)
			log.trace("autorize: end S09DocumentOfTemplate result = {}", result);

		if(strcmp("null", authorizedElementId) != 0 && iterator_facts_of_document is null && strcmp(
				authorizedElementCategory, semargl.Category.DOCUMENT.ptr) == 0)
		{
			if(f_authorization_trace)
				log.trace("return autorize: #2, return:[false]");

			return false;
		}
		if(f_authorization_trace)
			log.trace("autorize: end #2");

		if(semargl.scripts.S11ACLRightsHierarhical.calculate(User, authorizedElementId, targetRightType, ts,
				hierarhical_departments_or_delegates, pp, authorizedElementCategory))
		{
			if(f_authorization_trace)
				log.trace("return autorize: S11ACLRightsHierarhical return:[true]");

			return true;
		}
		if(f_authorization_trace)
			log.trace("autorize: end S11ACLRightsHierarhical");

		if(semargl.scripts.S10UserIsAuthorOfDocument.calculate(User, authorizedElementId, targetRightType, ts,
				iterator_facts_of_document))
		{
			if(f_authorization_trace)
				log.trace("return autorize: S10UserIsAuthorOfDocument return:[true]");

			return true;
		}
		if(f_authorization_trace)
			log.trace("autorize: end S10UserIsAuthorOfDocument");

		foreach(condition; conditions)
		{
			if(calculate_condition(User, condition, iterator_facts_of_document, hierarhical_departments_or_delegates,
					targetRightType) == true)
			{
				if(f_authorization_trace)
					log.trace("return autorize: calculate_condition return:[true]");
				return true;
			}
		}
		if(f_authorization_trace)
			log.trace("autorize: end calculate_condition");

		if(isAdmin)
		{
			if(f_authorization_trace)
				log.trace("return autorize: isAdmin = {}", true);
			return true;
		}

		if(f_authorization_trace)
			log.trace("autorize: end isAdmin");

		if(f_authorization_trace)
			log.trace("return autorize: Access Denied, return:[false]");

		return false;
	}

	public void getAuthorizationRightRecords(char*[] fact_s, char*[] fact_p, char*[] fact_o, uint count_facts,
			char* result_buffer, mom_client from_client)
	{
		log.trace("запрос на выборку записей прав");

		int reply_to_id = 0;
		char* command_uid = fact_s[0];

		char* result_ptr = cast(char*) result_buffer;
		auto elapsed = new StopWatch();
		elapsed.start;

		char* queue_name = cast(char*) (new char[40]);

		if(triples_in_memory == false)
		{
			for(int i = 0; i < count_facts; i++)
			{
				if(strlen(fact_o[i]) > 0)
				{
					if(strcmp(fact_p[i], REPLY_TO.ptr) == 0)
					{
						reply_to_id = i;
					}
				}
			}

			char*[] s = new char*[count_facts];
			char*[] p = new char*[count_facts];
			char*[] o = new char*[count_facts];
			char*[] read_predicates = ["mo/at/acl#atS\0".ptr, "mo/at/acl#atSs\0".ptr, "mo/at/acl#atSsE\0".ptr,
					"mo/at/acl#cat\0".ptr, "mo/at/acl#rt\0".ptr, "mo/at/acl#tgS\0".ptr, "mo/at/acl#tgSs\0".ptr,
					"mo/at/acl#tgSsE\0".ptr, "mo/at/acl#dtF\0".ptr, "mo/at/acl#dtT\0".ptr, "mo/at/acl#eId\0".ptr];

			//			char*[] read_predicates = ["mo/at/acl#atS\0".ptr];

			{
				short jj = 0;
				for(int i = 0; i < count_facts; i++)
				{
					//					log.trace("arg: [{}][{}][{}]", getString (fact_s[i]), getString (fact_p[i]), getString (fact_o[i]));

					if(strcmp(fact_p[i], SET_FROM.ptr) == 0 || strcmp(fact_p[i], AUTHOR_SYSTEM.ptr) == 0 || strcmp(
							fact_p[i], AUTHOR_SUBSYSTEM.ptr) == 0 || strcmp(fact_p[i], AUTHOR_SUBSYSTEM_ELEMENT.ptr) == 0 || strcmp(
							fact_p[i], TARGET_SYSTEM.ptr) == 0 || strcmp(fact_p[i], TARGET_SUBSYSTEM.ptr) == 0 || strcmp(
							fact_p[i], TARGET_SUBSYSTEM_ELEMENT.ptr) == 0 || strcmp(fact_p[i], CATEGORY.ptr) == 0 || strcmp(
							fact_p[i], ELEMENT_ID.ptr) == 0)
					{
						//					log.trace("add {}", jj);
						s[jj] = fact_s[i];
						p[jj] = fact_p[i];
						o[jj] = fact_o[i];
						jj++;
					}
				}
				//				jj--;

				s.length = jj;
				p.length = jj;
				o.length = jj;
				triple_list_element* result_list = ts.getTriples(s, p, o, read_predicates);

				strcpy(queue_name, fact_o[reply_to_id]);

				*result_ptr = '<';
				strcpy(result_ptr + 1, command_uid);
				result_ptr += strlen(command_uid) + 1;
				strcpy(result_ptr, result_data_header_with_bracets.ptr);
				result_ptr += result_data_header_with_bracets.length;

				while(result_list !is null)
				{
					Triple* triple = result_list.triple;
					//					log.trace("# get_authorization_rights_records : triple = {:X4}", triple);

					if(triple !is null)
					{
						char* s1 = cast(char*) triple.s;
						char* p1 = cast(char*) triple.p;
						char* o1 = cast(char*) triple.o;

						strcpy(result_ptr++, "<");
						strcpy(result_ptr, s1);
						result_ptr += strlen(s1);
						strcpy(result_ptr, "><");
						result_ptr += 2;
						strcpy(result_ptr, p1);
						result_ptr += strlen(p1);
						strcpy(result_ptr, ">\"");
						result_ptr += 2;
						strcpy(result_ptr, o1);
						result_ptr += strlen(o1);
						strcpy(result_ptr, "\".");
						result_ptr += 2;
					}

					result_list = result_list.next_triple_list_element;
				}

				strcpy(result_ptr, "}.<");
				result_ptr += 3;
				strcpy(result_ptr, command_uid);
				result_ptr += strlen(command_uid);
				strcpy(result_ptr, result_state_ok_header.ptr);
				result_ptr += result_state_ok_header.length;
				*(result_ptr - 1) = 0;

				strcpy(queue_name, fact_o[reply_to_id]);

				send_result_and_logging_messages(queue_name, result_buffer, from_client, false);

				double time = elapsed.stop;
				log.trace("get authorization rights records time = {:d6} ms. ( {:d6} sec.)", time * 1000, time);

				return;
			}
		}
		//@@@@@ 
		//		ts.log_query = true;

		int authorize_id = 0;
		int from_id = 0;

		int author_system_id = 0;
		int author_subsystem_id = 0;
		int author_subsystem_element_id = 0;
		int target_system_id = 0;
		int target_subsystem_id = 0;
		int target_subsystem_element_id = 0;
		int category_id = 0;
		int elements_id = 0;

		byte patterns_cnt = 0;

		for(int i = 0; i < count_facts; i++)
		{
			if(strlen(fact_o[i]) > 0)
			{
				log.trace("pattern predicate = '{}'. pattern object = '{}' with length = {}", getString(fact_p[i]),
						getString(fact_o[i]), strlen(fact_o[i]));

				if(strcmp(fact_p[i], SET_FROM.ptr) == 0)
				{
					from_id = i;
				} else if(strcmp(fact_p[i], AUTHOR_SYSTEM.ptr) == 0)
				{
					patterns_cnt++;
					author_system_id = i;
				} else if(strcmp(fact_p[i], AUTHOR_SUBSYSTEM.ptr) == 0)
				{
					patterns_cnt++;
					author_subsystem_id = i;
				} else if(strcmp(fact_p[i], AUTHOR_SUBSYSTEM_ELEMENT.ptr) == 0)
				{
					patterns_cnt++;
					author_subsystem_element_id = i;
				} else if(strcmp(fact_p[i], TARGET_SYSTEM.ptr) == 0)
				{
					patterns_cnt++;
					target_system_id = i;
				} else if(strcmp(fact_p[i], TARGET_SUBSYSTEM.ptr) == 0)
				{
					patterns_cnt++;
					target_subsystem_id = i;
				} else if(strcmp(fact_p[i], TARGET_SUBSYSTEM_ELEMENT.ptr) == 0)
				{
					patterns_cnt++;
					target_subsystem_element_id = i;
				} else if(strcmp(fact_p[i], CATEGORY.ptr) == 0)
				{
					patterns_cnt++;
					category_id = i;
				} else if(strcmp(fact_p[i], ELEMENT_ID.ptr) == 0)
				{
					patterns_cnt++;
					elements_id = i;
				} else if(strcmp(fact_p[i], REPLY_TO.ptr) == 0)
				{
					reply_to_id = i;
				}
			}
		}

		//		uint* SET = ts.getTriples("6fcb52fc46889ba8", null, null);
		//		fact_tools.print_list_triple(SET);

		triple_list_element* start_facts_set = null;
		byte start_set_marker = 0;
		if(elements_id > 0)
		{
			log.trace("@elements_id");
			start_facts_set = ts.getTriples(null, ELEMENT_ID.ptr, fact_o[elements_id]);
		} else if(target_subsystem_element_id > 0)
		{
			log.trace("@target_subsystem_element_id");
			start_set_marker = 1;
			start_facts_set = ts.getTriples(null, null, fact_o[target_subsystem_element_id]);
		} else if(author_subsystem_element_id > 0)
		{
			log.trace("@author_subsystem_element_id");
			start_set_marker = 2;
			//			start_facts_set = ts.getTriples(null, null, fact_o[author_subsystem_element_id]);
			start_facts_set = ts.getTriples(null, AUTHOR_SUBSYSTEM_ELEMENT.ptr, fact_o[author_subsystem_element_id]);
		} else if(category_id > 0)
		{
			log.trace("@category_id");
			start_set_marker = 3;
			start_facts_set = ts.getTriples(null, null, fact_o[category_id]);
		} else if(author_subsystem_id > 0)
		{
			log.trace("@category_id");
			start_set_marker = 4;
			start_facts_set = ts.getTriples(null, null, fact_o[author_subsystem_id]);
		} else if(target_subsystem_id > 0)
		{
			log.trace("@target_subsystem_id");
			start_set_marker = 5;
			start_facts_set = ts.getTriples(null, null, fact_o[target_subsystem_id]);
		} else if(author_system_id > 0)
		{
			log.trace("@author_system_id");
			start_set_marker = 6;
			start_facts_set = ts.getTriples(null, null, fact_o[author_system_id]);
		} else if(target_system_id > 0)
		{
			log.trace("@target_system_id");
			start_set_marker = 7;
			start_facts_set = ts.getTriples(null, null, fact_o[target_system_id]);
		}

		triple_list_element* start_facts_set_FE = start_facts_set;

		//		print_list_triple (start_facts_set);

		//		log.trace("elements_id = {}, author_subsystem_element_id = {}, target_subsystem_element_id = {}", elements_id, author_subsystem_element_id,
		//				target_subsystem_element_id);
		//		log.trace("category_id = {}, author_subsystem_id = {}, target_subsystem_id = {}, author_system_id = {}, target_system_id = {}", category_id,
		//				author_subsystem_id, target_subsystem_id, author_system_id, target_system_id);
		//		log.trace("start_set_marker = {}", start_set_marker);

		strcpy(queue_name, fact_o[reply_to_id]);

		*result_ptr = '<';
		strcpy(result_ptr + 1, command_uid);
		result_ptr += strlen(command_uid) + 1;
		strcpy(result_ptr, result_data_header_with_bracets.ptr);
		result_ptr += result_data_header_with_bracets.length;

		if(start_facts_set !is null)
		{
			while(start_facts_set !is null)
			{
				Triple* triple = start_facts_set.triple;
				//				log.trace("# get_authorization_rights_records : triple = {:X4}", triple);

				if(triple !is null)
				{
					char* s = cast(char*) triple.s;

					triple_list_element* founded_facts = ts.getTriples(s, null, null);
					triple_list_element* founded_facts_copy = founded_facts;
					triple_list_element* founded_facts_FE = founded_facts;

					if(founded_facts !is null)
					{
						bool is_match = true;
						byte checked_patterns_cnt = 1;
						while(founded_facts !is null)
						{
							Triple* triple1 = founded_facts.triple;

							if(triple1 !is null)
							{
								char* p1 = cast(char*) triple1.p;
								char* o1 = cast(char*) triple1.o;

								if(start_set_marker < 1 && target_subsystem_element_id > 0 && strcmp(p1,
										TARGET_SUBSYSTEM_ELEMENT.ptr) == 0)
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[target_subsystem_element_id]) == 0);
								}
								if(start_set_marker < 2 && author_subsystem_element_id > 0 && strcmp(p1,
										AUTHOR_SUBSYSTEM_ELEMENT.ptr) == 0)
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[author_subsystem_element_id]) == 0);
								}
								if(start_set_marker < 3 && (category_id > 0 && strcmp(p1, CATEGORY.ptr) == 0))
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[category_id]) == 0);
								}
								if(start_set_marker < 4 && author_subsystem_id > 0 && strcmp(p1, AUTHOR_SUBSYSTEM.ptr) == 0)
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[author_subsystem_id]) == 0);
								}
								if(start_set_marker < 5 && target_subsystem_id > 0 && strcmp(p1, TARGET_SUBSYSTEM.ptr) == 0)
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[target_subsystem_id]) == 0);
								}
								if(start_set_marker < 6 && author_system_id > 0 && strcmp(p1, AUTHOR_SYSTEM.ptr) == 0)
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[author_system_id]) == 0);
								}
								if(start_set_marker < 7 && target_system_id > 0 && strcmp(p1, TARGET_SYSTEM.ptr) == 0)
								{
									checked_patterns_cnt++;
									is_match = is_match & (strcmp(o1, fact_o[target_system_id]) == 0);
								}

							}

							founded_facts = founded_facts.next_triple_list_element;

						}

						//						log.trace("is_match = {} checked_patterns_cnt = {} patterns_cnt = {} ", is_match, checked_patterns_cnt, patterns_cnt);

						if(is_match && checked_patterns_cnt == patterns_cnt)
						{
							//log.trace("found match");
							while(founded_facts_copy !is null)
							{
								Triple* triple1 = founded_facts_copy.triple;
								//log.trace("#3");
								if(triple1 !is null)
								{
									//log.trace("...not null");
									char* p1 = cast(char*) triple1.p;
									char* o1 = cast(char*) triple1.o;

									strcpy(result_ptr++, "<");
									strcpy(result_ptr, s);
									result_ptr += strlen(s);
									strcpy(result_ptr, "><");
									result_ptr += 2;
									strcpy(result_ptr, p1);
									result_ptr += strlen(p1);
									strcpy(result_ptr, ">\"");
									result_ptr += 2;
									strcpy(result_ptr, o1);
									result_ptr += strlen(o1);
									strcpy(result_ptr, "\".");
									result_ptr += 2;
								}

								founded_facts_copy = founded_facts_copy.next_triple_list_element;
							}

						}

						ts.list_no_longer_required(founded_facts_FE);

						if(strlen(result_buffer) > 10000)
						{
							strcpy(result_ptr, "}.\0");

							// отправляем multi-part message
							send_result_and_logging_messages(queue_name, result_buffer, from_client, true);

							//							client.send(queue_name, result_buffer);

							result_ptr = cast(char*) result_buffer;

							*result_ptr = '<';
							strcpy(result_ptr + 1, command_uid);
							result_ptr += strlen(command_uid) + 1;
							strcpy(result_ptr, result_data_header_with_bracets.ptr);
							result_ptr += result_data_header_with_bracets.length;

						}
					}
				}
				start_facts_set = start_facts_set.next_triple_list_element;
			}
		}

		ts.list_no_longer_required(start_facts_set_FE);

		strcpy(result_ptr, "}.<");
		result_ptr += 3;
		strcpy(result_ptr, command_uid);
		result_ptr += strlen(command_uid);
		strcpy(result_ptr, result_state_ok_header.ptr);
		result_ptr += result_state_ok_header.length;
		*(result_ptr - 1) = 0;

		strcpy(queue_name, fact_o[reply_to_id]);

		send_result_and_logging_messages(queue_name, result_buffer, from_client, false);

		//		client.send(queue_name, result_buffer);

		//@@@@@ 
		//		ts.log_query = false;

		double time = elapsed.stop;
		log.trace("get authorization rights records time = {:d6} ms. ( {:d6} sec.)", time * 1000, time);
		//		log.trace("result:{}\n sent to: {}", getString(result_buffer), getString(queue_name));

	}

	public void getDelegateAssignersTree(char*[] fact_s, char*[] fact_p, char*[] fact_o, int arg_id, uint count_facts,
			char* result_buffer, mom_client from_client)
	{

		log.trace("команда на выборку делегировавших");

		auto elapsed = new StopWatch();
		elapsed.start;

		int reply_to_id = 0;
		for(int i = 0; i < count_facts; i++)
		{
			if(strlen(fact_o[i]) > 0)
			{
				if(strcmp(fact_p[i], REPLY_TO.ptr) == 0)
				{
					reply_to_id = i;
				}
			}
		}

		char* queue_name = cast(char*) (new char[40]);
		strcpy(queue_name, fact_o[reply_to_id]);

		//log.trace("#1 gda");

		char* result_ptr = cast(char*) result_buffer;
		char* command_uid = fact_s[0];
		strcpy(queue_name, fact_o[reply_to_id]);

		*result_ptr = '<';
		strcpy(result_ptr + 1, command_uid);
		result_ptr += strlen(command_uid) + 1;
		strcpy(result_ptr, result_data_header.ptr);
		result_ptr += result_data_header.length;

		bool put_in_result(Triple* founded_delegate)
		{
			version(trace)
				log.trace("добавим делегата <{}><{}>\"{}\" в список", fromStringz(founded_delegate.s), fromStringz(
						founded_delegate.p), fromStringz(founded_delegate.o));

			strcpy(result_ptr++, ",");
			strcpy(result_ptr, founded_delegate.o);
			result_ptr += strlen(founded_delegate.o);

			return true;
		}

		getDelegateAssignersForDelegate(fact_o[arg_id], ts, &put_in_result);

		strcpy(result_ptr, "\".<");
		result_ptr += 3;
		strcpy(result_ptr, command_uid);
		result_ptr += strlen(command_uid);
		strcpy(result_ptr, result_state_ok_header.ptr);
		result_ptr += result_state_ok_header.length;
		*(result_ptr - 1) = 0;

		//		client.send(queue_name, result_buffer);
		send_result_and_logging_messages(queue_name, result_buffer, from_client, false);

		double time = elapsed.stop;
		log.trace("get delegate assigners time = {:d6} ms. ( {:d6} sec.)", time * 1000, time);
		//		log.trace("result:{} \nsent to:{}", getString(result_buffer), getString(queue_name));

	}

	public void getDelegators(char*[] fact_s, char*[] fact_p, char*[] fact_o, int arg_id, uint count_facts,
			char* result_buffer, mom_client from_client)
	{

		version(trace)
			log.trace("команда на выборку списка лиц делегировавших свои права");

		auto elapsed = new StopWatch();
		elapsed.start;

		int reply_to_id = 0;
		for(int i = 0; i < count_facts; i++)
		{
			if(strlen(fact_o[i]) > 0)
			{
				if(strcmp(fact_p[i], REPLY_TO.ptr) == 0)
				{
					reply_to_id = i;
				}
			}
		}

		char* queue_name = cast(char*) (new char[40]);
		strcpy(queue_name, fact_o[reply_to_id]);

		//log.trace("#1 gda");

		char* result_ptr = cast(char*) result_buffer;
		char* command_uid = fact_s[0];
		strcpy(queue_name, fact_o[reply_to_id]);

		*result_ptr = '<';
		strcpy(result_ptr + 1, command_uid);
		result_ptr += strlen(command_uid) + 1;
		strcpy(result_ptr, result_data_header_with_bracets.ptr);
		result_ptr += result_data_header_with_bracets.length;

		version(trace)
		{
			log.trace("getDelegators:arg = s={}", getString(fact_s[arg_id]));
			log.trace("getDelegators:arg = p={}", getString(fact_p[arg_id]));
			log.trace("getDelegators:arg = o={}", getString(fact_o[arg_id]));
		}

		triple_list_element* delegators_facts = ts.getTriples(null, DELEGATION_DELEGATE.ptr, fact_o[arg_id]);

		//		triple_list_element* delegates_facts_FE = delegates_facts;
		while(delegators_facts !is null)
		{
			Triple* delegator = delegators_facts.triple;
			if(delegator !is null)
			{
				char* dr_subject = cast(char*) delegator.s;
				version(trace)
				{
					log.trace("delegator = {}, count={}", getString(dr_subject), ts.get_count_form_list_triple(
							delegators_facts));
				}

				triple_list_element* delegate_records = ts.getTriples(dr_subject, null, null);

				char* dr_de;
				char* dr_ow;
				char* dr_df;
				char* dr_dt;
				char* dr_wt;
				char* dr_dc;

				while(delegate_records !is null)
				{
					Triple* dr = delegate_records.triple;

					version(trace)
					{
						log.trace("		facts = <{}><{}><{}>", getString(dr.s), getString(dr.p), getString(dr.o));
					}

					if(strcmp(dr.p, DELEGATION_DOCUMENT_ID.ptr) == 0)
					{
						dr_dc = cast(char*) dr.o;

					} else if(strcmp(dr.p, DELEGATION_OWNER.ptr) == 0)
					{
						dr_ow = cast(char*) dr.o;

					} else if(strcmp(dr.p, DELEGATION_DELEGATE.ptr) == 0)
					{
						dr_de = cast(char*) dr.o;

					} else if(strcmp(dr.p, DELEGATION_WITH_TREE.ptr) == 0)
					{
						dr_wt = cast(char*) dr.o;

					} else if(strcmp(dr.p, DATE_FROM.ptr) == 0)
					{
						dr_df = cast(char*) dr.o;

					} else if(strcmp(dr.p, DATE_TO.ptr) == 0)
					{
						dr_dt = cast(char*) dr.o;
					}
					delegate_records = delegate_records.next_triple_list_element;
				}

				bool is_actual = is_today_in_interval(dr_df, dr_dt);

				if(is_actual)
				{
					if(dr_ow !is null)
						result_ptr = print_triple_to_buff(result_ptr, dr_subject, DELEGATION_OWNER.ptr, dr_ow);

					if(dr_de !is null)
						result_ptr = print_triple_to_buff(result_ptr, dr_subject, DELEGATION_DELEGATE.ptr, dr_de);

					if(dr_dc !is null)
						result_ptr = print_triple_to_buff(result_ptr, dr_subject, DELEGATION_DOCUMENT_ID.ptr, dr_dc);
						
					if(dr_wt !is null)
						result_ptr = print_triple_to_buff(result_ptr, dr_subject, DELEGATION_WITH_TREE.ptr, dr_wt);

					if(dr_df !is null)
						result_ptr = print_triple_to_buff(result_ptr, dr_subject, DATE_FROM.ptr, dr_df);

					if(dr_dt !is null)
						result_ptr = print_triple_to_buff(result_ptr, dr_subject, DATE_TO.ptr, dr_dt);
				}
			}

			delegators_facts = delegators_facts.next_triple_list_element;
		}

		strcpy(result_ptr, "}.<");
		result_ptr += 3;
		strcpy(result_ptr, command_uid);
		result_ptr += strlen(command_uid);
		strcpy(result_ptr, result_state_ok_header.ptr);
		result_ptr += result_state_ok_header.length;
		*(result_ptr - 1) = 0;

		//		client.send(queue_name, result_buffer);
		send_result_and_logging_messages(queue_name, result_buffer, from_client, false);

		double time = elapsed.stop;

		version(trace)
		{
			log.trace("get delegators time = {:d6} ms. ( {:d6} sec.)", time * 1000, time);
		}
		//		log.trace("result:{} \nsent to:{}", getString(result_buffer), getString(queue_name));

	}

}

private char* print_triple_to_buff(char* result_ptr, char* s, char* p, char* o)
{
	*result_ptr = '<';
	strcpy(result_ptr + 1, s);
	result_ptr += strlen(s) + 1;
	*result_ptr = '>';
	result_ptr++;
	*result_ptr = '<';
	strcpy(result_ptr + 1, p);
	result_ptr += strlen(p) + 1;
	*result_ptr = '>';
	result_ptr++;
	*result_ptr = '"';
	strcpy(result_ptr + 1, o);
	result_ptr += strlen(o) + 1;
	*result_ptr = '"';
	result_ptr++;
	*result_ptr = '.';
	result_ptr++;

	return result_ptr;
}