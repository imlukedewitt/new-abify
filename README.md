# ABify

ABify is a workflow automation tool designed to process large datasets by orchestrating complex, multi-step API interactions. It is particularly well-suited for data import tasks that require fetching, transforming, and posting data to external services.

This project is very much a work in progress

## Core Concepts

The system is built around a few key ideas:

*   **Workflows:** A configurable series of steps that define the process a piece of data will go through.
*   **Data Sources:** The input data to be processed, typically a collection of rows (e.g., from a CSV file).
*   **Steps:** An individual action within a workflow, which is usually a single API call.

## Key Features

*   **Dynamic and Flexible Processing:** Workflows are highly configurable using Liquid templating. This allows for dynamic generation of API requests (URLs, parameters, and bodies) and custom logic for handling responses based on the input data from each row.

*   **High-Volume Data Processing:** The system is designed for speed and efficiency. It processes API calls concurrently and supports batching, which allows for grouping related data to be processed sequentially while other data is handled in parallel.

*   **Designed for API-Driven Imports:** ABify excels at workflows that require multiple dependent API calls to complete a single task, such as looking up related records before creating a new entity in a target system.

## How It Works

At a high level, a `Workflow` is executed against a `DataSource`. The engine iterates through each row of data, performing the sequence of `Steps` defined in the workflow. Data from API responses can be extracted and used in subsequent steps, allowing for complex, chained operations.
