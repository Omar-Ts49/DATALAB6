# Clinic Management CLI

A command-line interface for managing clinic operations, including patient lists, appointment scheduling, inventory monitoring, and staff sharing.

## Prerequisites

Before using this CLI, ensure you have the required environment setup with all necessary libraries installed. The project was developed in a custom environment with specific dependencies as per the lab instructions.

## Installation

1. Clone this repository
2. Ensure you have Python installed
3. Make sure all required libraries are installed in your environment

## Usage

Run the following commands from your terminal:

### List Patients
```bash
python cli.py list_patients
```

### Schedule Appointment
```bash
python cli.py schedule_appt --caid "input_value" --iid "input_value" --staff "input_value" --dep "input_value" --date "YYYY-MM-DD" --time "HH:MM:SS" --reason "input_value"
```

### Check Low Stock
```bash
python cli.py low_stock
```

### Staff Share
```bash
python cli.py staff_share
```
