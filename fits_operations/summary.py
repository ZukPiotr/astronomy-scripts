import os
from astropy.io import fits
from collections import defaultdict

def summarize_fits_objects(directory_path):
    objects_info = defaultdict(lambda: defaultdict(int))
    fits_files = []

    for file in os.listdir(directory_path):
        if file.lower().endswith(('.fits', '.fit', '.fts')):
            fits_files.append(os.path.join(directory_path, file))

    if not fits_files:
        print("No FITS files found in this directory.")
        return

    for file_path in fits_files:
        try:
            with fits.open(file_path) as hdul:
                header = hdul[0].header
                obj_name = header.get('OBJECT', 'UNKNOWN').strip()
                filter_name = header.get('FILTER', 'UNKNOWN').strip()
                
                objects_info[obj_name][filter_name] += 1
        except Exception as e:
            print(f"Failed to read file {file_path}: {e}")

    if not objects_info:
        print("Could not collect data from any FITS files.")
        return
        
    print("\n--- GENERAL SUMMARY ---")
    for obj_name, filters in objects_info.items():
        total_image_count = sum(filters.values())
        print(f"OBJECT: {obj_name:<20} | Total image count: {total_image_count}")

    print("\n--- DETAILED SUMMARY (per filter) ---")
    for obj_name, filters in objects_info.items():
        print(f"\nOBJECT: {obj_name}")
        for filter_name, count in filters.items():
            print(f"  -> FILTER: {filter_name:<10} | Image count: {count}")
    print("-" * 50)

if __name__ == "__main__":
    path_to_images = '.'
    print(f"Analyzing FITS files in the current directory...")
    summarize_fits_objects(path_to_images)
