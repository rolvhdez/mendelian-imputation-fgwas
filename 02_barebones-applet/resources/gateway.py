import re
import numpy as np
import pandas as pd
import os,sys
import time
import threading

class Spinner:
    """Spinning animation to know that a process is running"""
    def __init__(self, message: str = "Loading..."):
        self.spinner_chars = "|/-\\"
        self.running = False
        self.thread = None
        self.message = message

    def spin(self):
        while self.running:
            for char in self.spinner_chars:
                sys.stdout.write(f"\r{self.message}... [{char}]")
                sys.stdout.flush()
                time.sleep(0.1)

    def start(self):
        self.running = True
        self.thread = threading.Thread(target=self.spin)
        self.thread.start()

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join()
        sys.stdout.write(f"\r{self.message} Done! \n")
        sys.stdout.flush()

class Data_Gateway:
    def __init__(self,filepath:str):
        self.__filepath = filepath
        
    def load_csv(self): 
        """Reads comma separated files"""
        loading = Spinner(message=f"Reading {self.__filepath}")
        loading.start()
        df = pd.read_csv(self.__filepath)
        loading.stop()
        return df
    
    def load_table(self):
        """Reads plain tabular separated files"""
        loading = Spinner(message=f"Reading {self.__filepath}")
        loading.start()
        df = pd.read_table(self.__filepath)
        loading.stop()
        return df # this change 
    
    @staticmethod
    def export(file_df: dict, output_dir: str = 'output',
               extension: str = 'txt', sep: str = '\t',
               temp: bool = False):
        """
        Exports DataFrames to files in the specified directory.

        Args:
            file_df (dict): A dictionary to list the filenames to export and what dataframe it belongs.
            output_dir (str): Directory to export. Defaults to 'output'.
            extension (str): File extension to export DataFrame. Defaults to 'txt'.
            sep (str): Separator for DataFrame. Dafaults to '\t' (tabs).
            temp (bool): Exports files as temporary in root. Defaults to False.
        """

        if temp == True:
            output_dir = "/tmp/"
        
        # Create the output directory if it doesn't exist
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        # Export each DataFrame to a file
        for filename, df in file_df.items():
            filepath = os.path.join(output_dir, f'{filename}.{extension}')
            
            loading = Spinner(message = f"Exporting {filename}.{extension}...")
            loading.start()
            df.to_csv(filepath, sep=sep, index=False)
            loading.stop()