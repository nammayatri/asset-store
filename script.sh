#!/bin/bash

# Define the source and target repositories
TARGET_REPOS=("https://github.com/nammayatri/nammayatri")
branch_name=$1

files_to_be_added=()

add_file_for_commit() { #dir , sub_dir, asset_type, asset_name, source_path
    local dir="$1"
    local sub_dir="$2"
    local asset_type="$3"
    local asset_name="$4"
    local updated_path="Frontend/android-native/app/src/$dir/$sub_dir/res/$asset_type/$asset_type"
    files_to_be_added+=("$source_path:$updated_path")
}

# Function to create a Pull Request
create_pull_request() {
    local target_repo="$TARGET_REPOS"
    local target_repo_name="$(basename "$target_repo")" || { echo "Error: Invalid target repository URL"; return 1; }

    if [ -z "$branch_name" ]; then
        echo "Error: Branch name not provided"
        return 1
    fi

    # Check if there are staged files
    local staged_files
    staged_files="$(git diff --cached --name-only)" || { echo "Error: Failed to retrieve staged files"; return 1; }

    declare -a staged_files_array

    while IFS= read -r line; do
        staged_files_array+=("$line")
    done <<< "$staged_files"
    echo $target_repo_name

    # Clone or update the target repository
    
    git clone "$target_repo" || { echo "Error: Failed to clone repository"; return 1; }
    cd "$target_repo_name" || { echo "Error: Directory $target_repo_name does not exist after cloning"; return 1; }

    git branch -D "$branch_name" >/dev/null 2>&1 || true
    git checkout -b "$branch_name" || { echo "Error: Failed to create or checkout branch $branch_name"; return 1; }
    git pull origin --rebase main || { echo "Error: Failed to pull latest changes"; return 1; }


    # Process staged files and copy them to appropriate locations
    local allowed_extensions=("png" "jpg" "xml" "json")
    local filestobeadded=()

    for file in "${staged_files_array[@]}"; do
    extension="${file##*.}"

    if [[ " ${allowed_extensions[@]} " =~ " $extension " ]]; then
        source_path="$file"
        IFS="/" read -ra src_path_components <<< "$source_path"
        
        # Determine file type based on path_components[3]
        if [[ ${src_path_components[3]} == "images" ]]; then
            file_type="drawable"
        else
            file_type="raw"
        fi

        dir=${src_path_components[2]}
        dir_array=()
        sub_dir=${src_path_components[1]}
        asset_type=${file_type}
        asset_name=${src_path_components[4]}

        # Adjust sub_dir and dir_array based on conditions
        if [[ ${src_path_components[2]} == "driver" ]]; then
            sub_dir="${src_path_components[1]}Partner"
        elif [[ ${src_path_components[2]} == "${src_path_components[1]}common" ]]; then 
            dir_array=("user" "driver")
        else
            dir_array+=("$dir")
        fi

        # Iterate through dir_array and call add_file_for_commit
        for dir in "${dir_array[@]}"; do 
            add_file_for_commit "$dir" "$sub_dir" "$asset_type" "$asset_name" "$source_path"
        done
    fi

    for item in "${files_to_be_added[@]}"; do
      source_path="${item%:*}"
      updated_path="${item#*:}"
      cp "../$source_path" "$updated_path"
    done

    git add .
    git commit -m "Add new asset from asset store"
    git push origin "$branch_name" || { echo "Error: Failed to push changes to branch $branch_name"; return 1; }
    pull_request_url="${target_repo}/compare/main...${branch_name}"
    echo "Pull request URL: $pull_request_url"

}


# Loop through target repositories and create pull requests
for target_repo in "${TARGET_REPOS[@]}"; do
    create_pull_request "$target_repo" "$target_repo"
done

