# DeployLens

DeployLens is a tool for visualizing and analyzing GitHub Actions workflows. It provides a dashboard to monitor the status of your CI/CD pipelines, helping you identify bottlenecks and improve deployment frequency.

## Features

* **Real-time Dashboard:** View the status of all your workflows in a single place.
* **Workflow Analysis:** Get insights into workflow duration, success rates, and failure patterns.
* **GitHub Integration:** Connects to your GitHub repositories and listens for workflow events via webhooks.
* **Detailed Job Information:** Drill down into individual workflow runs to see job details and logs.

## Getting Started

To start your Phoenix server:

1. **Install dependencies:**

    ```bash
    mix setup
    ```

2. **Set up environment variables:**

    Create a `.env` file in the root of the project and add the following:

    ```
    GITHUB_WEBHOOK_SECRET=your_github_webhook_secret
    ```

3. **Start the Phoenix server:**

    ```bash
    mix phx.server
    ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Technology Stack

* **Backend:** Elixir, Phoenix
* **Frontend:** LiveView, Tailwind CSS
* **Database:** PostgreSQL

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License.

