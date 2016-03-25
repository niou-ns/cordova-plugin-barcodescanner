/*global cordova*/
module.exports = {

	show: function(options, success, failure) {
		cordova.exec(success, failure, "BarcodeCamera", "show", [options]);
	},

	close: function(options, success, failure) {
		cordova.exec(success, failure, "BarcodeCamera", "close", [options]);
	},

};
