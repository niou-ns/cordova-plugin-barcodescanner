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
        plist = context.requireCordovaModule('plist'),
        path = context.requireCordovaModule('path');

    if (fs.existsSync(FILEPATH)) {
      var xml = fs.readFileSync(FILEPATH, 'utf8');
      if (xml) {
        var obj = plist.parse(xml);

        obj.PreferenceSpecifiers.push({
            Type: 'PSGroupSpecifier',
            Title: 'Scanner'
          });

        obj.PreferenceSpecifiers.push({
            DefaultValue: true,
            Key: 'beep_sound',
            Title: 'Beep sound',
            Type: 'PSToggleSwitchSpecifier'
          });

        obj.PreferenceSpecifiers.push({
            DefaultValue: true,
            Key: 'vibrate',
            Title: 'Vibrate',
            Type: 'PSToggleSwitchSpecifier'
          });


        xml = plist.build(obj);
        fs.writeFileSync(FILEPATH, xml, { encoding: 'utf8' });
      }
    } else {
      // Thanks to Simon Seyock - http://stackoverflow.com/a/26038979
      copyFolderRecursiveSync(__dirname + '/../src/ios/Settings.bundle', 'platforms/ios/' + projectName + '/Resources');

      function copyFileSync( source, target ) {
          var targetFile = target;
          //if target is a directory a new file with the same name will be created
          if ( fs.existsSync( target ) ) {
              if ( fs.lstatSync( target ).isDirectory() ) {
                  targetFile = path.join( target, path.basename( source ) );
              }
          }
          fs.writeFileSync(targetFile, fs.readFileSync(source));
      }

      function copyFolderRecursiveSync( source, target ) {
          var files = [];
          //check if folder needs to be created or integrated
          var targetFolder = path.join( target, path.basename( source ) );
          if ( !fs.existsSync( targetFolder ) ) {
              fs.mkdirSync( targetFolder );
          }
          //copy
          if ( fs.lstatSync( source ).isDirectory() ) {
              files = fs.readdirSync( source );
              files.forEach( function ( file ) {
                  var curSource = path.join( source, file );
                  if ( fs.lstatSync( curSource ).isDirectory() ) {
                      copyFolderRecursiveSync( curSource, targetFolder );
                  } else {
                      copyFileSync( curSource, targetFolder );
                  }
              } );
          }
      }

    }

};
