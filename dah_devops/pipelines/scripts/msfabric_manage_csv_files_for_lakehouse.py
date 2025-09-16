"""Script for MS Fabric management of CSV files in Azure OneLake."""

# pylint: disable=W0621,W0718,C0103
import argparse
import os
from typing import List, Generator, Optional

from azure.identity import DefaultAzureCredential
from azure.storage.filedatalake import DataLakeServiceClient, DataLakeFileClient


def initialize_datalake(account_name: str) -> Optional[DataLakeServiceClient]:
    """
    Initializes the DataLake service client.
    """
    try:
        account_url = f"https://{account_name}.dfs.fabric.microsoft.com"
        credential = DefaultAzureCredential()
        service_client = DataLakeServiceClient(
            account_url, credential=credential
        )
        return service_client
    except Exception as e:
        print(f"Error initializing storage account: {e}")
        return None


def get_csv_file_paths(
    directory_client: DataLakeFileClient, directory_name: str
) -> Generator[str, None, None]:
    """
    A generator that yields CSV file paths in the given directory.
    """
    paths = directory_client.get_paths()
    for path in paths:
        if path.name.startswith(directory_name) and path.name.endswith(".csv"):
            yield path.name


def delete_csv_files_from_directory(
    service_client: DataLakeServiceClient,
    file_system_name: str,
    directory_name: str,
) -> None:
    """
    Deletes all CSV files in a specified directory within a OneLake file system.
    """
    try:
        file_system_client = service_client.get_file_system_client(
            file_system_name
        )
        directory_client = file_system_client.get_directory_client(
            directory_name
        )

        if not directory_client.exists():
            print(
                f"Directory '{directory_name}' does not exist. Skipping deletion."
            )
            return

        for csv_file_path in get_csv_file_paths(
            directory_client, directory_name
        ):
            file_client = file_system_client.get_file_client(csv_file_path)
            file_client.delete_file()
            print(f"Deleted file: {csv_file_path}")

        print(
            f"All CSV files in directory '{directory_name}' deleted successfully."
        )
    except Exception as e:
        print(f"Error deleting CSV files: {e}")


def get_local_files(csv_files: List[str]) -> Generator[str, None, None]:
    """
    A generator that yields local CSV files for upload.
    """
    for local_file_path in csv_files:
        if os.path.isfile(local_file_path):
            yield local_file_path
        else:
            print(
                f"File '{local_file_path}' does not exist or is not a valid file. Skipping."
            )


def upload_files_to_directory(
    service_client: DataLakeServiceClient,
    file_system_name: str,
    directory_name: str,
    csv_files: List[str],
) -> None:
    """
    Uploads multiple files to a specific directory within a OneLake file system.
    """
    try:
        file_system_client = service_client.get_file_system_client(
            file_system_name
        )
        directory_client = file_system_client.get_directory_client(
            directory_name
        )
        for local_file_path in get_local_files(csv_files):
            file_name = os.path.basename(local_file_path)
            file_client = directory_client.get_file_client(file_name)

            with open(local_file_path, "rb") as file:
                file_contents = file.read()

            file_client.upload_data(file_contents, overwrite=True)
            print(f"Uploaded: {file_name}")

        print("All files uploaded successfully.")
    except Exception as e:
        print(f"Error uploading files: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Delete existing CSV files and upload new CSV files to Azure OneLake."
    )
    parser.add_argument(
        "action",
        choices=["delete", "upload"],
        help="Action to perform: 'delete' to delete files or 'upload' to upload files.",
    )
    parser.add_argument(
        "csv_files",
        nargs="*",
        help="Paths to the local CSV files to upload. Not required for 'delete' action.",
    )
    parser.add_argument(
        "workspace_name",
        help="Name of the workspace in MS Fabric, e.g., GFCS IDL SIT.",
    )
    parser.add_argument(
        "directory_path",
        help="Path of the directory in OneLake where the files will be uploaded.",
    )

    args = parser.parse_args()

    account_name = "onelake"

    service_client = initialize_datalake(account_name)
    if service_client:
        if args.action == "delete":
            delete_csv_files_from_directory(
                service_client,
                args.workspace_name,
                args.directory_path,
            )

        elif args.action == "upload":
            if not args.csv_files:
                print("No CSV files provided for upload.")
            else:
                upload_files_to_directory(
                    service_client,
                    args.workspace_name,
                    args.directory_path,
                    args.csv_files,
                )
