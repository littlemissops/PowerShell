#####################################################################################
#    Export Script to pull more than 1000 Records into JSON                         #
#    for subsequent preprocessing                                                   #
#    Author: Barbara Schön, B.A, Littlemissops.at   V 1.072024                      #
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

# JIRA Credentials setzen: Skritp geht davon aus dass API User ein AD user ist der ebenfalls Schreibrechte auf ein Fileshare hat (nicht nötig bei lokaler Speicherung))


$JIRA_USERNAME = "<ReplaceWithyourJiraUser>"
$JIRA_PASSWORD = "<ReplaceWithyourJiraPW>"

#Konvertieren des Users/Passworts and zusammenbauen des Request-Headers
function ConvertTo-Base64($string) {
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
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

# JIRA Base URL für den API Call wird gesetzt 
$JIRA_BASE_URL = "https://<ReplaceWithyourJiraDomain>/rest/api/2/issue/"

# JIRA project keys werden in Array gespeichert.
# Dieses Script geht durch alle Projects!
# Nützlich für initialen Export!
# Momentan hardcoded, TODO: ev. dynamisch ziehen
$PROJECT_KEYS = @("<PRO1>","<PRO2>","<PRO3>")

# Paginierte Resultate wegen Performance! Hier die MAX Anzahl von ergebnissen pro Iteration eintragen
$ISSUES_PER_PAGE = 100

#Durch alle einträge in $Project_Keys iterieren
foreach ($PROJECT_KEY in $PROJECT_KEYS){

#Informationsoutput welches Projekt gerade verarbeitet wird und wie der Fortschritt ist.
Write-Host "Currently processing project key: $PROJECT_KEY"


# API API call URL um die erste Anzahl an issues ($issues_per_page) zu ziehen 
$FIRST_PAGE_URL = "https://<ReplaceWithyourJiraDomain>/rest/api/2/search?jql=project=$PROJECT_KEY&fields=key&maxResults=$ISSUES_PER_PAGE"

# Totale Anzahl von Issues ziehen
$Headers = Get-HttpBasicHeader $JIRA_USERNAME $JIRA_PASSWORD
$TOTAL_ISSUES = (Invoke-RestMethod -Uri $FIRST_PAGE_URL -Headers $Headers -Method Get).total

# Array initialisieren - issue keys werden hier gespeichert
$ISSUE_KEYS = @()

# Iteration durch alle Resultate und hinzufügen von Issue-Key zum Array
$offset = 0
do {
    # API Call URL für die aktuellen Resultate - Start at offset: die nächste iteration beginnt bei max(vorige)+1
    $URL = "https://<ReplaceWithyourJiraDomain>/rest/api/2/search?jql=project=$PROJECT_KEY&fields=key&maxResults=$ISSUES_PER_PAGE&startAt=$offset"

    # API Call um die Issue-Keys für den Durchgang zu bekommen
    $Headers = Get-HttpBasicHeader $JIRA_USERNAME $JIRA_PASSWORD
    $page_issues = (Invoke-RestMethod -Uri $URL -Headers $Headers -Method Get).issues
    $page_keys = $page_issues | ForEach-Object { $_.key }

    # Issue Keys zum Array hinzufügen
    $ISSUE_KEYS += $page_keys

    # Offset auf die nächste Einheit Resultate verschieben, solange es noch weniger als $TOTAL_ISSUES ist
    $offset += $ISSUES_PER_PAGE
} while ($offset -lt $TOTAL_ISSUES)

# Felder bestimmen die ins JSON File gezogen werden  - DIES HIER IST NUR EIN BEISPIEL!!! CUSTOMFIELD ID's SIND IN JEDEM JIRA ANDERS!!!!!
#
# Generelle Jira Felder: 
# key=Ticketnummer, Priority = JIRA Standard Priority für Ticket, zum Vergleich mit ML Resultat
# Summary = Betreff des Tickets
# Description = Ursprüngliche Problembeschreibung, Kundenanfrage
#
# Custom Fields in diesem Beispiel die
# customfield_10100 = Kunde
# reporter = Person die das Ticket geöffnet hat
# customfield_17801 = ML_Category  - wird später im Import Script verwendet und wird auch zur validiertung der Kategorien verwendet.
# customfield_11901 = Alte manuelle Kategorie zum Vergleich mit ML Resultat

$FIELDS = "key,priority,customfield_10100,reporter,summary,description,customfield_17801,customfield_11901"

#funktion eingebaut um Text bereits so weit wie möglich zu bereinigen
function Remove-Markup {  
    param (  
        [string]$Text  
    )  
  
    $Text -replace '\{[^}]*\}', '' -replace '<[^>]*>', '' -replace '\r\n', '' -replace '\\r\\n', '' -replace '\r', '' -replace '\n\n', '' -replace '\n', '' -replace '\*', ''  
} 

# Aus jedem Issue im Array wird nun die API CALL URL generiert für die oben gewählten Felder
foreach ($i in 0..($ISSUE_KEYS.Length - 1)) {
    $KEY = $ISSUE_KEYS[$i]
    $URL = $JIRA_BASE_URL + $KEY + "?fields=" + $FIELDS

    # API Call durchführen und JSON Datei speichern in NetworkShare mit ISSUE-KEY als Name
	# -NoClobber = existierende Files dürfen nicht überschrieben werden, somit werden später nur neue Files prozessiert
	# TODO:  Eventuell Datumseinschränkung einbauen - täglich laufender Job fuer neue Tickets....
    $Headers = Get-HttpBasicHeader $JIRA_USERNAME $JIRA_PASSWORD
    $Issue = Invoke-RestMethod -Uri $URL -Headers $Headers  -Method Get  
	
	#Markup aus der Description entfernen 
    $Issue.fields.description = Remove-Markup -Text $Issue.fields.description  
	
	$Issue | ConvertTo-Json | Out-File -FilePath "\\<REPLACE-WithYourStoragePath>\socrates\RAW\$($PROJECT_KEY)\$($KEY).json" -NoClobber
	


# Eine Statusbar gibt Information wie viel % der Totalen Issues bereits exportiert wurden.
	$percentComplete = ($i + 1) / $ISSUE_KEYS.Length * 100
    $status = "Exportiere Ticket $($i + 1) von $($ISSUE_KEYS.Length) ($($percentComplete.ToString("N0"))% complete)"
    Write-Progress -Activity "Exportiere Ticket aus Projekt $PROJECT_KEY" -Status $status -PercentComplete $percentComplete
    }

# Schliessen der Iterationsclausel für die Project Keys im Array
}