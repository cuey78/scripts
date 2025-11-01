#!/bin/python3
import os
import glob
import re

def get_highest_existing_number(prefix="wallpaper"):
    """Find the highest number used with the given prefix"""
    pattern = re.compile(rf"^{re.escape(prefix)}-(\d+)\..+$")
    max_number = 0
    
    for filename in os.listdir('.'):
        match = pattern.match(filename)
        if match:
            number = int(match.group(1))
            if number > max_number:
                max_number = number
    
    return max_number

def rename_images(prefix="wallpaper", start_number=None):
    # Define common image extensions
    image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp']
    
    # Get all image files in current directory (only files that don't match our naming pattern)
    image_files = []
    naming_pattern = re.compile(rf"^{re.escape(prefix)}-\d+\..+$")
    
    for extension in image_extensions:
        # Look for both lowercase and uppercase extensions
        pattern = f"*.{extension}"
        files = glob.glob(pattern) + glob.glob(pattern.upper())
        # Filter out files that already match our naming pattern
        for file in files:
            if not naming_pattern.match(file):
                image_files.append(file)
    
    # Remove duplicates and sort
    image_files = sorted(list(set(image_files)))
    
    if not image_files:
        print("No new image files found to rename.")
        print("Supported formats:", ", ".join(image_extensions))
        return
    
    print(f"Found {len(image_files)} new image files to rename:")
    for file in image_files:
        print(f"  - {file}")
    
    # Determine starting number
    if start_number is None:
        start_number = get_highest_existing_number(prefix) + 1
        print(f"Auto-detected starting number: {start_number}")
    
    # Ask for confirmation before renaming
    response = input(f"\nRename {len(image_files)} files starting from {start_number}? (y/n): ")
    if response.lower() != 'y':
        print("Cancelled.")
        return
    
    # Calculate padding for numbers (at least 3 digits)
    padding = max(3, len(str(len(image_files) + start_number - 1)))
    
    # Rename files
    counter = start_number
    renamed_count = 0
    
    for old_name in image_files:
        # Get file extension
        _, ext = os.path.splitext(old_name)
        
        # Create new name with zero-padding
        new_name = f"{prefix}-{counter:0{padding}d}{ext}"
        
        # Rename the file
        try:
            os.rename(old_name, new_name)
            print(f"Renamed: {old_name} -> {new_name}")
            counter += 1
            renamed_count += 1
        except OSError as e:
            print(f"Error renaming {old_name}: {e}")
    
    print(f"\nRenaming completed! {renamed_count} files renamed.")

if __name__ == "__main__":
    rename_images(prefix="wallpaper")  # No start_number - it will auto-detect
