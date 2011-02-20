package components
{
	import flash.events.Event;
	import flash.events.MouseEvent;
 	import flash.net.navigateToURL;
 	import flash.net.URLRequest;

	import mx.controls.Button;

	public class AttachmentButton extends Button
	{
		private var url:String;

		[Embed(source='/assets/icons/arrow_down.png')]
		private static const _downloadIcon:Class; 

		public function AttachmentButton(label:String, url:String, toolTip:String)
		{
			this.label = label;
			this.url = url;
			this.toolTip = toolTip;
			this.setStyle("icon", _downloadIcon);
			this.addEventListener(MouseEvent.CLICK, downloadAttachment);
		}

		private function downloadAttachment(event:Event):void {
			navigateToURL(new URLRequest(url));
		}
	}
}