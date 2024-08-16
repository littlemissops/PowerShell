#####################################################################################
#    Import Script to pull from JSON into JIRA from                                 #
#    TAGGED FILES #                                                                 #
#    Author: Barbara Schön, B.A, Littlemissops.at   V 1.082024                      #
#    Copyright [2024] [Barbara Schön, B.A.]                                         #
#                                                                                   #
#   Licensed under the Apache License, Version 2.0 (the "License");                 #
#   you may not use this file except in compliance with the License.                #
#   You may obtain a copy of the License at                                         #
#                                                                                   #
#      http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                                   #
#  Unless required by applicable law or agreed to in writing, software              #
#   distributed under the License is distributed on an "AS IS" BASIS,               #
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.        #
#   See the License for the specific language governing permissions and             #
#   limitations under the License                                                   #
#                                                                                   #
#####################################################################################

# Jira Credentials definieren
$JIRA_USERNAME = "<InsertJiraUsername>"
$JIRA_PASSWORD = "<InsertJiraPassword>"
# Projekte Definieren und Importpfad - Projekt Key ändern!
$projectkey = "PROJ"
$jsonDirPath = "<InsertPathToTaggedJsonFiles>\$projectkey"
# Alle Dateien aus dem Importpfad einlesen
$jsonFiles = Get-ChildItem -Path $jsonDirPath -Filter "*.json" -File
foreach ($jsonFile in $jsonFiles) {
# Issue Key (Ticketnummer) aus dem Dateinamen extrahieren
 $issueKey = $jsonFile.BaseName
# Pfad zur JSON-Datei zusammenbauen
 $jsonFilePath = Join-Path $jsonDirPath $jsonFile.Name
# Daten aus der JSON Datei einlesen
 $json = Get-Content $jsonFilePath -Raw
# REST API URL definieren
 $url = "<InsertJiraBaseURL>/rest/api/2/issue/$issueKey"
#Konvertieren des Users/Passworts and zusammenbauen des Request-Headers
 function ConvertTo-Base64($string) {
 $bytes = [System.Text.Encoding]::UTF8.GetBytes($string);
 $encoded = [System.Convert]::ToBase64String($bytes);
 return $encoded;
 }
 function Get-HttpBasicHeader([string]$JIRA_USERNAME, [string]$JIRA_PASSWORD, $Headers = @{}) {
 $b64 = ConvertTo-Base64 "$($JIRA_USERNAME):$($JIRA_PASSWORD)"
 $Headers["Authorization"] = "Basic $b64"
 $Headers["X-Atlassian-Token"] = "nocheck"
 $Headers["Content-Type"] = "application/json; charset=utf-8;"
 return $Headers
 }
# REST API aufrufen und Jira Issue aktualisieren
 $Headers = Get-HttpBasicHeader $JIRA_USERNAME $JIRA_PASSWORD
 Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $json
# Ausgabe an welchem ticket gerade gearbeitet wird 
 Write-Host "Currently updating project key: $PROJECTKEY and $issueKey"
}