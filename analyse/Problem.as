package analyse
{
	public class Problem
	{
		public var num:uint;
		public var problem:String;
		[Bindable]
		public var status:String;
		public function Problem(num:uint, problem:String, status:String)
		{
			this.num = num;
			this.problem = problem;
			this.status = status;
		}
	}
}