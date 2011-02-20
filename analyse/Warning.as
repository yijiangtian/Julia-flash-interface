package analyse
{
	public class Warning
	{
		public var where:String;
		public var warning:String;
		public var problems:Array;
		[Bindable]
		public var falseAlarm:Boolean;

		public function Warning(where:String, warning:String, problems:Array, falseAlarm:Boolean)
		{
			this.where = where;
			this.warning = warning;
			this.problems = problems;
			this.falseAlarm = falseAlarm;
		}

	}
}