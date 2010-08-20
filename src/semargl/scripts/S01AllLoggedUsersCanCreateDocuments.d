module semargl.scripts.S01AllLoggedUsersCanCreateDocuments;

private import tango.io.Stdout;

private import semargl.RightTypeDef;
private import semargl.Predicates;
private import trioplax.TripleStorage;

public bool calculate(uint rightType)
{
	//	Stdout.format("S01AllLoggedUsersCanCreateDocuments is run... rightType={}", rightType).newline;

	if(rightType == RightType.CREATE)
	{
		return true;
	}
	return false;
}