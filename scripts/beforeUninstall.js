#!/usr/bin/env node
var cordova_util = require('cordova-lib/src/cordova/util');
var projectRoot = cordova_util.isCordova(process.cwd());
var projectXml = cordova_util.projectConfig(projectRoot);
var ConfigParser = require('cordova-lib').configparser;
var projectConfig = new ConfigParser(projectXml);
var projectName = projectConfig.name();

var FILEPATH = 'platforms/ios/' + projectName + '/Resources/Settings.bundle/Root.plist';

module.exports = function (context) {

    if (context.opts.cordova.platforms.indexOf('ios') < 0) {
      return;
    }

    var fs = context.requireCordovaModule('fs')
        plist = context.requireCordovaModule('plist');

    if (fs.existsSync(FILEPATH)) {
      var xml = fs.readFileSync(FILEPATH, 'utf8');
    }

    if (xml) {
      var obj = plist.parse(xml);

      for (var i = 0; i < obj.PreferenceSpecifiers.length; i++) {
        if (obj.PreferenceSpecifiers[i].Title === 'Scanner' || obj.PreferenceSpecifiers[i].Title === 'SCANNER_TITLE') {
          obj.PreferenceSpecifiers.splice(i, 3);
          break;
        }
      }
      if (!obj.PreferenceSpecifiers.length > 0) {
        var path = 'platforms/ios/' + projectName + '/Resources/Settings.bundle';
        
        if( fs.existsSync(path) ) {
          fs.readdirSync(path).forEach(function(file,index){
            var curPath = path + "/" + file;
            if(fs.lstatSync(curPath).isDirectory()) {
              deleteFolderRecursive(curPath);
            } else {
              fs.unlinkSync(curPath);
            }
          });
          fs.rmdirSync(path);
        }
      } else {
        xml = plist.build(obj);
        fs.writeFileSync(FILEPATH, xml, { encoding: 'utf8' });
      }
    }

};
