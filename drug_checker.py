#!/usr/bin/env python3
"""
Drug Interaction Checker MVP
100% Free | Local AI | Privacy-First
"""

import requests
from prettytable import PrettyTable
import json
import os
from datetime import datetime
from pathlib import Path

# ============================================================================
# CONFIGURATION
# ============================================================================

OPENFDA_LABEL_ENDPOINT = "https://api.fda.gov/drug/label.json"
OLLAMA_API = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "llama3.2"

DATA_DIR = Path("drug_checker_data")
MY_MEDS_FILE = DATA_DIR / "my_medications.json"
HISTORY_FILE = DATA_DIR / "check_history.json"
CACHE_FILE = DATA_DIR / "interaction_cache.json"

RED_KEYWORDS = [
    "contraindicated", "life-threatening", "fatal", "avoid", "do not", 
    "serious", "severe", "dangerous", "death", "emergency"
]
YELLOW_KEYWORDS = [
    "caution", "monitor", "risk", "may increase", "use with care",
    "decrease", "interfere", "reduce", "affect", "alter"
]

# ============================================================================
# SETUP & UTILITIES
# ============================================================================

def setup_data_directory():
    """Create data directory if it doesn't exist."""
    DATA_DIR.mkdir(exist_ok=True)
    
    # Initialize files if they don't exist
    if not MY_MEDS_FILE.exists():
        save_json(MY_MEDS_FILE, [])
    if not HISTORY_FILE.exists():
        save_json(HISTORY_FILE, [])
    if not CACHE_FILE.exists():
        save_json(CACHE_FILE, {})

def load_json(filepath):
    """Load JSON file safely."""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except:
        return [] if filepath != CACHE_FILE else {}

def save_json(filepath, data):
    """Save JSON file safely."""
    try:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception as e:
        print(f"⚠️ Error saving {filepath.name}: {e}")
        return False

# ============================================================================
# DRUG DATA FETCHING
# ============================================================================

def get_drug_interactions(drug_name, limit=3):
    """Fetch drug interaction data from OpenFDA."""
    params = {"search": f"drug_interactions:{drug_name}", "limit": limit}
    try:
        response = requests.get(OPENFDA_LABEL_ENDPOINT, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        results = []
        for entry in data.get("results", []):
            interactions = entry.get("drug_interactions", [])
            if interactions:
                interactions_text = " ".join(interactions) if isinstance(interactions, list) else interactions
                results.append(interactions_text)
        return results if results else ["No interaction data found"]
    except requests.exceptions.Timeout:
        return ["Error: Request timed out"]
    except requests.exceptions.RequestException as e:
        return [f"Error: {str(e)}"]

def search_drug_suggestions(partial_name, limit=5):
    """Search for drug name suggestions from OpenFDA."""
    try:
        params = {
            "search": f"openfda.brand_name:{partial_name}*",
            "limit": limit
        }
        response = requests.get(OPENFDA_LABEL_ENDPOINT, params=params, timeout=5)
        response.raise_for_status()
        data = response.json()
        
        suggestions = set()
        for entry in data.get("results", []):
            brand_names = entry.get("openfda", {}).get("brand_name", [])
            generic_names = entry.get("openfda", {}).get("generic_name", [])
            suggestions.update([name.lower() for name in brand_names[:2]])
            suggestions.update([name.lower() for name in generic_names[:2]])
        
        return list(suggestions)[:limit]
    except:
        return []

# ============================================================================
# SEVERITY DETECTION
# ============================================================================

def detect_severity(text):
    """Detect interaction severity based on keywords."""
    text_lower = text.lower()
    
    # Check for high severity
    if any(keyword in text_lower for keyword in RED_KEYWORDS):
        return "🔴 High"
    
    # Check for moderate severity
    elif any(keyword in text_lower for keyword in YELLOW_KEYWORDS):
        return "🟡 Moderate"
    
    # Default to low if data exists but no keywords found
    return "🟢 Low"

# ============================================================================
# AI SUMMARIZATION
# ============================================================================

def summarize_with_ollama(raw_text, drug1, drug2):
    """Use Ollama locally to generate patient-friendly summary."""
    
    # Check if raw_text indicates no data
    if "No interaction data" in raw_text or "Error:" in raw_text:
        return raw_text
    
    prompt = f"""Read this FDA data about {drug1} and {drug2}. Write ONLY 2-3 short sentences explaining the interaction risk to a patient. Do not include any introduction, greeting, or extra text.

FDA Data:
{raw_text[:1500]}

Patient summary (2-3 sentences only):"""

    try:
        payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 100,
                "stop": ["\n\n", "Note:", "Important:", "Disclaimer:"]
            }
        }
        
        response = requests.post(OLLAMA_API, json=payload, timeout=60)
        response.raise_for_status()
        
        result = response.json()
        summary = result['response'].strip()
        
        # Clean up common chatty patterns
        cleanup_phrases = [
            "Here's a summary", "Here is a summary", "In plain English:",
            "For you:", "Patient summary:", f"between {drug1} and {drug2}",
            "of the FDA drug interaction data", "FDA data shows", "According to"
        ]
        
        for phrase in cleanup_phrases:
            summary = summary.replace(phrase, "")
        
        # Remove extra whitespace
        summary = " ".join(summary.split())
        
        # Limit to 3 sentences
        sentences = summary.split('. ')
        if len(sentences) > 3:
            summary = '. '.join(sentences[:3]) + '.'
        
        return summary.strip() if summary.strip() else raw_text[:200]
    
    except requests.exceptions.ConnectionError:
        return "⚠️ Ollama not running. Please start Ollama service."
    except requests.exceptions.Timeout:
        return "⚠️ AI summary timed out. Using raw data."
    except Exception as e:
        return f"⚠️ AI error: {str(e)}"

# ============================================================================
# CACHING
# ============================================================================

def get_cache_key(drug1, drug2):
    """Generate cache key from two drug names."""
    return "-".join(sorted([drug1.lower(), drug2.lower()]))

def get_cached_result(drug1, drug2):
    """Get cached interaction result if available."""
    cache = load_json(CACHE_FILE)
    key = get_cache_key(drug1, drug2)
    return cache.get(key)

def cache_result(drug1, drug2, severity, summary):
    """Cache interaction result for faster future lookups."""
    cache = load_json(CACHE_FILE)
    key = get_cache_key(drug1, drug2)
    cache[key] = {
        "severity": severity,
        "summary": summary,
        "timestamp": datetime.now().isoformat()
    }
    save_json(CACHE_FILE, cache)

# ============================================================================
# HISTORY TRACKING
# ============================================================================

def add_to_history(drug1, drug2, severity, summary):
    """Add check to history."""
    history = load_json(HISTORY_FILE)
    history.append({
        "drug1": drug1,
        "drug2": drug2,
        "severity": severity,
        "summary": summary,
        "timestamp": datetime.now().isoformat()
    })
    # Keep only last 100 entries
    if len(history) > 100:
        history = history[-100:]
    save_json(HISTORY_FILE, history)

def show_history(limit=10):
    """Display recent check history."""
    history = load_json(HISTORY_FILE)
    
    if not history:
        print("\n📜 No history yet.\n")
        return
    
    print(f"\n📜 Recent Checks (last {min(limit, len(history))}):")
    print("=" * 70)
    
    for entry in reversed(history[-limit:]):
        timestamp = datetime.fromisoformat(entry['timestamp']).strftime("%Y-%m-%d %H:%M")
        print(f"\n[{timestamp}] {entry['drug1']} + {entry['drug2']}")
        print(f"   {entry['severity']}: {entry['summary'][:80]}...")

# ============================================================================
# MEDICATION LIST MANAGEMENT
# ============================================================================

def get_my_medications():
    """Get saved medication list."""
    return load_json(MY_MEDS_FILE)

def add_medication(drug_name):
    """Add medication to saved list."""
    meds = get_my_medications()
    drug_clean = drug_name.lower().strip()
    
    if drug_clean in meds:
        print(f"\n✓ {drug_name} is already in your medication list.")
        return False
    
    meds.append(drug_clean)
    if save_json(MY_MEDS_FILE, meds):
        print(f"\n✓ Added {drug_name} to your medication list.")
        return True
    return False

def remove_medication(drug_name):
    """Remove medication from saved list."""
    meds = get_my_medications()
    drug_clean = drug_name.lower().strip()
    
    if drug_clean not in meds:
        print(f"\n⚠️ {drug_name} is not in your medication list.")
        return False
    
    meds.remove(drug_clean)
    if save_json(MY_MEDS_FILE, meds):
        print(f"\n✓ Removed {drug_name} from your medication list.")
        return True
    return False

def show_my_medications():
    """Display saved medication list."""
    meds = get_my_medications()
    
    if not meds:
        print("\n💊 No medications saved yet.\n")
        return
    
    print("\n💊 Your Medications:")
    print("=" * 70)
    for i, med in enumerate(meds, 1):
        print(f"{i}. {med.title()}")
    print()

def check_against_my_meds(new_drug):
    """Check a new drug against all saved medications."""
    meds = get_my_medications()
    
    if not meds:
        print("\n⚠️ No saved medications to check against. Add some first!")
        return
    
    print(f"\n🔍 Checking {new_drug} against {len(meds)} saved medication(s)...\n")
    
    results = []
    for med in meds:
        result = check_interaction(med, new_drug, show_progress=False)
        results.append(result)
    
    # Display all results
    for result in results:
        print(result)
        print()

# ============================================================================
# INTERACTION CHECKING
# ============================================================================

def check_interaction(drug1, drug2, show_progress=True, use_cache=True):
    """Main function to check drug interactions."""
    drug1 = drug1.lower().strip()
    drug2 = drug2.lower().strip()
    
    if show_progress:
        print(f"\n🔍 Checking: {drug1.title()} + {drug2.title()}")
    
    # Check cache first
    if use_cache:
        cached = get_cached_result(drug1, drug2)
        if cached:
            if show_progress:
                print("   ⚡ Using cached result...")
            
            table = PrettyTable()
            table.field_names = ["Drug A", "Drug B", "Severity", "Summary"]
            table.max_width["Summary"] = 60
            table.add_row([drug1.title(), drug2.title(), cached['severity'], cached['summary']])
            
            add_to_history(drug1, drug2, cached['severity'], cached['summary'])
            return table
    
    # Fetch fresh data
    if show_progress:
        print(f"   📡 Fetching {drug1} data...")
    drug1_texts = get_drug_interactions(drug1)
    
    if show_progress:
        print(f"   📡 Fetching {drug2} data...")
    drug2_texts = get_drug_interactions(drug2)
    
    combined = " ".join(drug1_texts + drug2_texts)
    
    # Check for errors or no data
    if "No interaction data" in combined or "Error:" in combined:
        severity = "⚪ Unknown"
        summary = "No interaction data available in FDA database. Consult healthcare provider."
    else:
        if show_progress:
            print(f"   🎯 Analyzing severity...")
        severity = detect_severity(combined)
        
        if show_progress:
            print(f"   🤖 Generating AI summary...")
        summary = summarize_with_ollama(combined, drug1, drug2)
    
    # Cache the result
    cache_result(drug1, drug2, severity, summary)
    
    # Add to history
    add_to_history(drug1, drug2, severity, summary)
    
    # Create result table
    table = PrettyTable()
    table.field_names = ["Drug A", "Drug B", "Severity", "Summary"]
    table.max_width["Summary"] = 60
    table.add_row([drug1.title(), drug2.title(), severity, summary])
    
    return table

# ============================================================================
# EXPORT FUNCTIONALITY
# ============================================================================

def export_history_to_text():
    """Export history to a text file."""
    history = load_json(HISTORY_FILE)
    
    if not history:
        print("\n⚠️ No history to export.\n")
        return
    
    filename = f"drug_interaction_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    filepath = DATA_DIR / filename
    
    try:
        with open(filepath, 'w') as f:
            f.write("=" * 70 + "\n")
            f.write("DRUG INTERACTION CHECK HISTORY\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("=" * 70 + "\n\n")
            
            for entry in reversed(history):
                timestamp = datetime.fromisoformat(entry['timestamp']).strftime("%Y-%m-%d %H:%M")
                f.write(f"[{timestamp}]\n")
                f.write(f"Drugs: {entry['drug1'].title()} + {entry['drug2'].title()}\n")
                f.write(f"Severity: {entry['severity']}\n")
                f.write(f"Summary: {entry['summary']}\n")
                f.write("-" * 70 + "\n\n")
        
        print(f"\n✓ History exported to: {filepath}\n")
    except Exception as e:
        print(f"\n⚠️ Error exporting history: {e}\n")

# ============================================================================
# USER INTERFACE
# ============================================================================

def print_header():
    """Print application header."""
    print("\n" + "=" * 70)
    print("DRUG INTERACTION CHECKER - MVP Edition")
    print("=" * 70)
    print("🆓 100% Free | 🔒 Private | 🤖 Local AI (Ollama)")
    print("=" * 70)

def print_menu():
    """Print main menu."""
    print("\n" + "─" * 70)
    print("MAIN MENU")
    print("─" * 70)
    print("1. Check two drugs")
    print("2. Check new drug against my medications")
    print("3. Manage my medications")
    print("4. View history")
    print("5. Export history")
    print("6. Clear cache")
    print("7. Quit")
    print("─" * 70)

def manage_medications_menu():
    """Medication management submenu."""
    while True:
        print("\n" + "─" * 70)
        print("MANAGE MEDICATIONS")
        print("─" * 70)
        print("1. View my medications")
        print("2. Add medication")
        print("3. Remove medication")
        print("4. Back to main menu")
        print("─" * 70)
        
        choice = input("\nChoice: ").strip()
        
        if choice == "1":
            show_my_medications()
        elif choice == "2":
            drug = input("\nEnter medication name to add: ").strip()
            if drug:
                add_medication(drug)
            else:
                print("\n⚠️ Please enter a medication name.")
        elif choice == "3":
            show_my_medications()
            drug = input("\nEnter medication name to remove: ").strip()
            if drug:
                remove_medication(drug)
            else:
                print("\n⚠️ Please enter a medication name.")
        elif choice == "4":
            break
        else:
            print("\n⚠️ Invalid choice. Please try again.")

def get_drug_input(prompt):
    """Get drug name from user with suggestions."""
    drug = input(prompt).strip().lower()
    
    if not drug:
        return None
    
    # If drug is very short, offer suggestions
    if len(drug) >= 3:
        suggestions = search_drug_suggestions(drug)
        if suggestions and drug not in suggestions:
            print(f"\n💡 Suggestions: {', '.join(suggestions[:5])}")
            use_suggestion = input("Use one of these? (y/n): ").strip().lower()
            if use_suggestion == 'y':
                print("\nSuggested drugs:")
                for i, sug in enumerate(suggestions[:5], 1):
                    print(f"{i}. {sug.title()}")
                choice = input("Choose number (or press Enter to use your original): ").strip()
                if choice.isdigit() and 1 <= int(choice) <= len(suggestions):
                    drug = suggestions[int(choice) - 1]
                    print(f"✓ Using: {drug.title()}")
    
    return drug

def clear_cache():
    """Clear interaction cache."""
    confirm = input("\n⚠️ Clear all cached interactions? (y/n): ").strip().lower()
    if confirm == 'y':
        save_json(CACHE_FILE, {})
        print("\n✓ Cache cleared.\n")
    else:
        print("\n✓ Cache not cleared.\n")

def main():
    """Main application loop."""
    setup_data_directory()
    print_header()
    
    # Quick Ollama check
    try:
        requests.get("http://localhost:11434", timeout=2)
        print("✓ Ollama detected and running")
    except:
        print("⚠️ Warning: Ollama may not be running. Start it for AI summaries.")
    
    while True:
        print_menu()
        choice = input("\nChoice: ").strip()
        
        if choice == "1":
            # Check two drugs
            drug_a = get_drug_input("\nEnter first drug name: ")
            if not drug_a:
                print("⚠️ Please enter a drug name.")
                continue
            
            drug_b = get_drug_input("Enter second drug name: ")
            if not drug_b:
                print("⚠️ Please enter a drug name.")
                continue
            
            result = check_interaction(drug_a, drug_b)
            print(result)
        
        elif choice == "2":
            # Check against saved meds
            drug = get_drug_input("\nEnter new drug name to check: ")
            if drug:
                check_against_my_meds(drug)
            else:
                print("⚠️ Please enter a drug name.")
        
        elif choice == "3":
            # Manage medications
            manage_medications_menu()
        
        elif choice == "4":
            # View history
            limit_input = input("\nShow how many recent checks? (default 10): ").strip()
            limit = int(limit_input) if limit_input.isdigit() else 10
            show_history(limit)
        
        elif choice == "5":
            # Export history
            export_history_to_text()
        
        elif choice == "6":
            # Clear cache
            clear_cache()
        
        elif choice == "7" or choice.lower() in ['quit', 'exit', 'q']:
            print("\n👋 Thanks for using Drug Interaction Checker!")
            print("💡 Remember: Always consult healthcare professionals for medical advice.\n")
            break
        
        else:
            print("\n⚠️ Invalid choice. Please try again.")

# ============================================================================
# ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted. Goodbye!\n")
    except Exception as e:
        print(f"\n⚠️ Unexpected error: {e}\n")