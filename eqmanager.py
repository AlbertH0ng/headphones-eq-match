import autoeq
import json

def get_eq_profile(headphone_name):
    try:
        results = autoeq.get_results(headphone_name)
        if results:
            return results[0].parametric_eq
        else:
            return None
    except Exception as e:
        print(f"Error getting EQ profile: {str(e)}")
        return None

def calculate_eq_difference(input_headphones, output_headphones):
    input_profile = get_eq_profile(input_headphones)
    output_profile = get_eq_profile(output_headphones)
    
    if input_profile is None or output_profile is None:
        return None
    
    difference = []
    for i in range(len(input_profile)):
        diff = {
            "freq": input_profile[i]["freq"],
            "q": input_profile[i]["q"],
            "gain": output_profile[i]["gain"] - input_profile[i]["gain"]
        }
        difference.append(diff)
    
    return difference

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python eqmanager.py <input_headphones> <output_headphones>")
        sys.exit(1)
    
    input_headphones = sys.argv[1]
    output_headphones = sys.argv[2]
    
    difference = calculate_eq_difference(input_headphones, output_headphones)
    if difference:
        print(json.dumps(difference))
    else:
        print("Error calculating EQ difference")