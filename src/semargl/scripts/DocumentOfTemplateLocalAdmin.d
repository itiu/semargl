module semargl.scripts.DocumentOfTemplateLocalAdmin;

private import tango.stdc.string;

private import semargl.Predicates;
private import semargl.Category;
private import trioplax.TripleStorage;
private import semargl.RightTypeDef;
private import semargl.Log;
private import trioplax.triple;
private import semargl.scripts.S11ACLRightsHierarhical;

public bool calculate(char* user, char* elementId, uint rightType, TripleStorage ts, char*[] array_of_targets_of_hierarhical_departments,
		char[] pp)
{
	version (trace)
	    log.trace("DocumentOfTemplateLocalAdmin");

	bool result = false;

	if(elementId is null || *elementId == '*')
	{
		log.trace("Неподдерживаемый идентификатор : {}.", elementId);
		return false;
	}

	Triple* template_triple;
	triple_list_element* facts = ts.getTriples(elementId, DOCUMENT_TEMPLATE_ID.ptr, null);
	if(facts !is null)
	{
		template_triple = facts.triple;
		if(template_triple !is null)
		{
			char*	template_id = cast(char*) template_triple.o;

			result = semargl.scripts.S11ACLRightsHierarhical.checkRight(user, template_id, RightType.DELETE, ts, array_of_targets_of_hierarhical_departments, pp,
					DOCUMENTS_OF_TEMPLATE.ptr);
										
			//authorizedElementCategory);	
		}
		ts.list_no_longer_required (facts);

	}
	//	else
	//		log.trace("S09 template_id not found");

	return result;

}