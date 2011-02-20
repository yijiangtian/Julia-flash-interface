package help
{
    import flash.utils.ByteArray;

    import mx.core.FlexGlobals;
    import mx.controls.Alert;
    import mx.containers.TitleWindow;
    import mx.controls.Label;
    import mx.managers.PopUpManager;
    import mx.core.Application;
    
    public final class Helper
    {
        [Embed("/assets/help/jars.txt", mimeType="application/octet-stream")]
        private static const jarsTextClass: Class;
        public static const jarsText:String = new jarsTextClass().toString();

        [Embed("/assets/help/nullness.txt", mimeType="application/octet-stream")]
        private static const nullnessTextClass: Class;
        public static const nullnessText:String = new nullnessTextClass().toString();

        [Embed("/assets/help/termination.txt", mimeType="application/octet-stream")]
        private static const terminationTextClass: Class;
        public static const terminationText:String = new terminationTextClass().toString();

        [Embed("/assets/help/checks.txt", mimeType="application/octet-stream")]
        private static const checksTextClass: Class;
        public static const checksText:String = new checksTextClass().toString();

        [Embed("/assets/help/contacts.txt", mimeType="application/octet-stream")]
        private static const contactsTextClass: Class;
        public static const contactsText:String = new contactsTextClass().toString();

        [Embed("/assets/help/credits.txt", mimeType="application/octet-stream")]
        private static const creditsTextClass: Class;
        public static const creditsText:String = new creditsTextClass().toString();

        [Embed("/assets/help/technical_information.txt", mimeType="application/octet-stream")]
        private static const technicalInformationTextClass: Class;
        public static const technicalInformationText:String = new technicalInformationTextClass().toString();

        [Embed("/assets/help/buy.txt", mimeType="application/octet-stream")]
        private static const buyTextClass: Class;
        public static const buyText:String = new buyTextClass().toString();

        public function Helper() {}

        public function jars():void {
            Alert.show(jarsText, "Jars");
        }

        public function contacts():void {
            Alert.show(contactsText, "Contacts");
        }

        public function credits():void {
            Alert.show(creditsText, "Credits");
        }

        public function technical_information():void {
            Alert.show(technicalInformationText, "Technical Information");
        }

        public function buy():void {
            /*
            const w:TitleWindow = new TitleWindow();
            const j:Julia = FlexGlobals.topLevelApplication as Julia;
            w.title = "Buy Julia";
            w.width = j.width / 1.5;
            w.height = j.height / 1.5;
            const l:Label = new Label();
            l.htmlText = buyText;
            l.condenseWhite = true;
            w.addChild(l);
            PopUpManager.addPopUp(w, j, true);
            PopUpManager.centerPopUp(w);
            */
            Alert.show(buyText, "Buy Julia");
        }
    }
}