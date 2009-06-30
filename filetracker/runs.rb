#Bibliotheken aufrufen
require "rubygems"
#require "mysql"
require "cgi"
require 'yaml'

puts ARGV.to_yaml
exit 1

#runs auslesen und Tabellenzeilen generieren
def run_liste(conn, cgi)
  #SQL- Abfrage
  result = conn.query(
    "SELECT run_id, user, title, host, parameter_id, key, valueend
    FROM runs, parameters
    WHERE run_id=parameter_id
    OREDER BY run_id"
    )
    ausgabe =""
    #Wenn Datensaetze vorhanden sind...
    if result.num_rows > 0
      #...zeilenweise hinzufuegen
      while row = result.fetch_hash
        ausgabe +=
        cgi.tr {
          cgi.td { row['run_id']} +
          cgi.td { row['user']} +
          cgi.td { row['title']} +
          cgi.td { row['host']}
          }
        end
      end
      #Fertigen String zurueckgeben
      ausgabe
    end

#Datenbankverbindung
conn = Mysql.new("localhost","root","testen")
#Standarddatenbank
conn.select_db("yaml")

#Neuen Datensatz eingeben?

# Daten auslesen

#runs ueberpruefen

#run neu?

#runs einfuegen

