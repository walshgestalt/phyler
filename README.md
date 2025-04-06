<pre style="font-size: 10px;">


                                                                                                
                                                                                                 
                                   ███████    ██████                                             
         ████████   █████    █████    ███      █    ███████      ████ █████  █████ ████          
        ██     ██   ██       ███        ███  █         ██          ███          ███    ███       
       ███████     ██  ████  ██           ██           ██           ██   ██      ███████         
      ██          ███       ███           ██           ██        █   ██       █   ███   ███      
  ████████     ███████   ████████      ████████      █████████████ █████████████ ███████   █████ 
                                                                                                 
                                                                                                 
                                                        </pre>


Phyler is a modular metaprogram framework designed for text analysis and interactive visualization. Inspired by phylogenetic systematics, Phyler allows users to explore text data through clustering and phenetic methods, generating navigable web directories with interactive graphs. Built with OCaml and leveraging D3.js for dynamic visualizations, it is a powerful tool for researchers and developers working with text data.
Features

    Modular Design: Easily extendable with interchangeable modules for input handling, preprocessing, clustering, and rendering.
    Distance Metrics: Supports multiple metrics such as Levenshtein distance and semantic similarity.
    Clustering Algorithms: Includes UPGMA and other clustering methods for grouping text data.
    Interactive Visualizations: Generates dynamic web graphs using D3.js, allowing users to explore data relationships.
    GitHub Integration: Manages configurations via GitHub forks, enabling collaborative experimentation.
    Configuration Database: Tracks different configurations and their outcomes for comparative analysis.

Installation
To set up Phyler on your local machine, follow these steps:

    Clone the Repository:
    bash

    git clone https://github.com/your-username/phyler.git

    Navigate to the Project Directory:
    bash

    cd phyler

    Install Dependencies:
        OCaml: Ensure OCaml is installed, then run:
        bash

        opam install ocamlbuild ocamlfind yojson uri

        Python: For database integration scripts:
        bash

        pip install requests

Usage
Quick Start

    Build the Project:
    bash

    ocamlbuild -use-ocamlfind src/main.native

    Run with Sample Configuration:
    bash

    ./main.native configs/sample_config.json sample_input.txt

    View the Output:
    Open output/index.html in a web browser to explore the interactive visualization.

Detailed Usage

    Running the Compiler:
    bash

    ./main.native <config_file> <input_file>

        <config_file>: Path to the configuration JSON file (e.g., configs/config.json).
        <input_file>: Path to the input text file.
    Output:
    The compiler generates a navigable web directory in ./output/, with:
        index.html: The main interactive graph serving as a sitemap.
        pages/: Individual HTML pages for each node, linked from the graph.

Configuration
Phyler uses JSON configuration files to customize its behavior. A sample configuration (configs/sample_config.json) is provided:
json

{
  "distance_metric": "levenshtein",
  "clustering_method": "upgma",
  "hyperlink_template": "node.html?cluster={cluster}&meta={meta}&distance={distance}&tamp={timestamp}",
  "visualization_type": "circular_cladistics"
}

    distance_metric: Specifies the metric for text comparison (e.g., "levenshtein", "semantic").
    clustering_method: Defines the clustering algorithm (e.g., "upgma").
    hyperlink_template: Template for generating URLs for node pages.
    visualization_type: Type of visualization (e.g., "circular_cladistics", "matrix_space").

To use a different configuration, either:

    Copy the desired configuration to configs/config.json.
    Specify the path to the configuration file when running the compiler.

Contributing
We welcome contributions to Phyler! To contribute:

    Fork the Repository.
    Create a New Branch for your feature or fix.
    Make Your Changes and commit them with descriptive messages.
    Submit a Pull Request to the main branch.

Please adhere to the coding standards outlined in docs/coding_standards.md.
License
This project is licensed under the MIT License. See the LICENSE file for details.
Contact
For questions, suggestions, or issues, please:

    Open an issue on GitHub.
    Contact the maintainers at [email@example.com (mailto:email@example.com)].

Additional Notes

    Prerequisites: Ensure you have OCaml and Python installed on your system.
    Output Description: The generated index.html contains an interactive graph where nodes represent text inputs or clusters, and edges represent relationships based on the chosen distance metric and clustering method.
    Extending Phyler: Thanks to its modular design, you can easily add new modules for different distance metrics, clustering algorithms, or visualization types.

Below is a detailed simulation of a developer workflow for the Phyler project, which you can include in the README afterward to guide new developers through a typical contribution process. This simulation covers cloning the repository, setting up the environment, making changes, testing, and submitting a pull request.
Developer Workflow Simulation
This section provides a step-by-step simulation of a typical developer workflow for contributing to the Phyler project. It walks you through cloning the repository, setting up your development environment, implementing a change, testing it, and submitting a pull request.
Step 1: Fork and Clone the Repository

    Fork the Repository:
        Visit the Phyler GitHub page at github.com/your-username/phyler.
        Click the "Fork" button to create a copy of the repository under your GitHub account.
    Clone Your Fork:
        Use the following command to clone the repository to your local machine:
        bash

        git clone https://github.com/your-github-username/phyler.git
        cd phyler

    Add the Upstream Remote:
        Link your fork to the original repository to stay updated:
        bash

        git remote add upstream https://github.com/original-owner/phyler.git

Step 2: Set Up the Development Environment

    Install Dependencies:
        OCaml: Install OCaml and its required packages:
        bash

        opam install ocamlbuild ocamlfind yojson uri

        Python: Install Python dependencies for database integration scripts:
        bash

        pip install requests

    Build the Project:
        Compile the project using OCamlbuild:
        bash

        ocamlbuild -use-ocamlfind src/main.native

    Run with Sample Configuration:
        Test the setup with a sample configuration and input file:
        bash

        ./main.native configs/sample_config.json sample_input.txt

    View the Output:
        Open output/index.html in a web browser to confirm the project runs correctly.

Step 3: Make Changes
Let’s simulate adding a new distance metric, "Hamming distance," to the project.

    Create a New Branch:
        Start by creating a feature branch for your changes:
        bash

        git checkout -b feature/hamming-distance

    Implement the New Metric:
        Edit src/preprocess.ml to add the new distance metric to the compute_distances function:
        ocaml

        | "hamming" -> List.map (fun t -> float_of_int (String.length t)) texts (* Placeholder *)

        Update the configuration files (e.g., configs/sample_config.json) to support the new metric.
    Update Documentation:
        Add a description of the Hamming distance metric to docs/modular_design.md to keep the documentation current.

Step 4: Test Your Changes

    Run Tests:
        Check if the test suite in src/test.ml covers the new metric. If not, add relevant tests.
        Build and run the tests:
        bash

        ocamlbuild -use-ocamlfind src/test.native && ./test.native

    Manual Testing:
        Modify configs/config.json to use the new metric:
        json

        {
          "distance_metric": "hamming",
          "clustering_method": "upgma",
          "hyperlink_template": "node.html?cluster={cluster}&meta={meta}&distance={distance}&tamp={timestamp}",
          "visualization_type": "circular_cladistics"
        }

        Run the project:
        bash

        ./main.native configs/config.json sample_input.txt

        Open output/index.html to verify the output reflects the new metric.

Step 5: Commit and Push Changes

    Stage Your Changes:
        Add the modified files to the staging area:
        bash

        git add src/preprocess.ml docs/modular_design.md configs/config.json

    Commit with a Descriptive Message:
        Commit your changes with a clear message:
        bash

        git commit -m "Add Hamming distance metric to preprocessing"

    Push to Your Fork:
        Push the branch to your GitHub fork:
        bash

        git push origin feature/hamming-distance

Step 6: Submit a Pull Request

    Go to Your Fork on GitHub:
        Navigate to your fork at https://github.com/your-github-username/phyler.
    Create a Pull Request:
        Find your branch and click "Compare & pull request."
        Add a title (e.g., "Add Hamming Distance Metric") and a detailed description of your changes.
        Submit the pull request to the main branch of the original repository.
    Respond to Feedback:
        If reviewers request changes, make them in your branch and push the updates. The pull request will reflect the new commits automatically.

Step 7: Sync with Upstream
To keep your fork aligned with the original repository:

    Fetch Upstream Changes:
        Pull the latest changes from the original repository:
        bash

        git fetch upstream

    Merge Upstream Changes:
        Switch to your main branch, merge the updates, and push them to your fork:
        bash

        git checkout main
        git merge upstream/main
        git push origin main

This workflow provides a clear, repeatable process for contributing to Phyler, ensuring that new developers can set up their environment, implement features, test them thoroughly, and collaborate effectively via pull requests while keeping their fork up-to-date. 
