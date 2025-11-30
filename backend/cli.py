import os
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import errorcode
load_dotenv()
cfg = dict(
host=os.getenv("MYSQL_HOST"),
port=int(os.getenv("MYSQL_PORT", 3306)),
database=os.getenv("MYSQL_DB"),
user=os.getenv("MYSQL_USER"),
password=os.getenv("MYSQL_PASSWORD"),
)
def get_connection():
    return mysql.connector.connect(**cfg)
def list_patients_ordered_by_last_name(limit=20):
    sql = """
    SELECT IID, FullName
    FROM Patient
    ORDER BY SUBSTRING_INDEX(FullName, ' ', -1), FullName
    LIMIT %s
    """
    with get_connection() as cnx:
        with cnx.cursor(dictionary=True) as cur:
            cur.execute(sql, (limit,))
            results = cur.fetchall()  # fetch inside the context
    return results

def insert_patient(iid, cin, full_name, birth, sex, blood, phone):
    sql = """
    INSERT INTO Patient(IID, CIN, FullName, Birth, Sex, BloodGroup, Phone)
    VALUES (%s , %s , %s , %s , %s , %s , %s )
    """
    with get_connection() as cnx:
        try:
            with cnx.cursor() as cur:
                cur.execute(sql, (iid, cin, full_name, birth, sex, blood, phone))
            cnx.commit()
        except Exception:
            cnx.rollback()
            raise
'''
if __name__ == "__main__":
    for row in list_patients_ordered_by_last_name():
        print(f"{ row['IID']} { row['FullName']} ")  # this is what forces out the printing of the first query without calling it.

'''

# Transactions across multiple statements. 

def schedule_appointment(caid, iid, staff_id, dep_id, date_str, time_str, reason):
    ins_ca = """
    INSERT INTO ClinicalActivity(CAID, IID, STAFF_ID, DEP_ID, Date, Time)
    VALUES (%s , %s , %s , %s , %s , %s )
    """
    ins_appt = """
    INSERT INTO Appointment(CAID, Reason, Status)
    VALUES (%s , %s , 'Scheduled')
    """
    with get_connection() as cnx:
        try:
            with cnx.cursor() as cur:
                cur.execute(ins_ca, (caid, iid, staff_id, dep_id, date_str, time_str))
                cur.execute(ins_appt, (caid, reason))
            cnx.commit()
        except Exception:
            cnx.rollback()
            raise

def low_stock():
    sql = """
    SELECT m.MID, s.HID
    FROM Medication m
    LEFT JOIN Stock s ON m.MID = s.MID
    WHERE s.MID IS NULL OR s.Qty < s.ReorderLevel;
    """
    with get_connection() as cnx:
        with cnx.cursor(dictionary=True) as cur:
            cur.execute(sql)
            results = cur.fetchall()  # fetch inside the context
    return results

def staff_share() : 
    sql = """ WITH staff_hosp AS (
    SELECT c.STAFF_ID , d.HID , COUNT(*) AS n
    FROM Appointment a
    JOIN ClinicalActivity c ON c.CAID = a.CAID
    JOIN Department d ON d.DEP_ID = c.DEP_ID
    GROUP BY c.STAFF_ID , d.HID
    ) ,
    hosp_tot AS (
    SELECT d.HID , COUNT(*) AS n
    FROM Appointment a
    JOIN ClinicalActivity c ON c.CAID = a.CAID
    JOIN Department d ON d.DEP_ID = c.DEP_ID
    GROUP BY d.HID
    )
    SELECT sh.STAFF_ID , sh.HID , sh.n AS TotalAppointments ,
    ROUND (100 * sh.n / ht.n, 2) AS PctOfHospital
    FROM staff_hosp sh
    JOIN hosp_tot ht ON ht.HID = sh.HID ;"""
    with get_connection() as cnx : 
        with cnx.cursor(dictionary=True) as cur : 
            cur.execute(sql)
            results = cur.fetchall()  # fetch inside the context
    return results

 # Pandas integration for quick analysis
import pandas as pd
from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv
load_dotenv()
url = (
    "mysql+mysqlconnector://"
    f"{ os.getenv('MYSQL_USER')}:{os.getenv('MYSQL_PASSWORD')}"
    f"@{ os.getenv('MYSQL_HOST')}:{os.getenv('MYSQL_PORT')}/{os.getenv('MYSQL_DB')}"
)
engine = create_engine(url, pool_pre_ping=True)
q = text("""
SELECT M.MID, M.Name AS Drug, H.City, AVG(S.UnitPrice) AS AvgPrice
FROM Stock S
JOIN Medication M ON M.MID = S.MID
JOIN Hospital H ON H.HID = S.HID
GROUP BY M.MID, M.Name, H.City
""")
df = pd.read_sql(q, engine)
#print(df.head()) Is this valid, since it is always printed no matter the command we execute.



import argparse
def main():
    parser = argparse.ArgumentParser(description="MNHS CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list_patients")
    appt = sub.add_parser("schedule_appt")
    appt.add_argument("--caid", type=int, required=True)
    appt.add_argument("--iid", type=int, required=True)
    appt.add_argument("--staff", type=int, required=True)
    appt.add_argument("--dep", type=int, required=True)
    appt.add_argument("--date", required=True) # YYYY-MM-DD
    appt.add_argument("--time", required=True) # HH:MM:SS
    appt.add_argument("--reason", required=True)
    sub.add_parser("low_stock") # no need to add arguments therefore this is enough to use the command
    sub.add_parser("staff_share") # no need to add arguments therefore this is enough to use the command
    
    args = parser.parse_args()
    if args.cmd == "list_patients":
        for r in list_patients_ordered_by_last_name():
            print(f"{ r['IID']} { r['FullName']} ")
    
    elif args.cmd == "schedule_appt":
        schedule_appointment(args.caid, args.iid, args.staff, args.dep,
        args.date, args.time, args.reason)
        print("Appointment scheduled")
    
    elif args.cmd == "low_stock":
        for m in low_stock(): # this returns the output of our query
            print(f"The medication of ID: {m['MID']} is below order level in the hospital of ID: {m['HID']}") #  list medications below ReorderLevel, as values in the dictionary returned by the function in the keys m.MID (column name) and s.HID:
    
    elif args.cmd == "staff_share" : 
        for s in staff_share() : # this returns the output of our query
            print(f"Staff of ID:{s['STAFF_ID']} that works in hospital of ID: {s['HID']}; Has a total of {s['TotalAppointments']} appointments. In a hospital of % {s['PctOfHospital']} ") 

if __name__ == "__main__":
    main()