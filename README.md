# $SOLIN - Sol Insights

## Overview
 The project automates the process of logging into a platform, fetching content from a specified endpoint, and posting that content to the platform using Selenium WebDriver.

### Environment Variables

Ensure the following environment variables are set in your `.env` file:

- `GENERATION_ENDPOINT`: The endpoint to fetch generated content.
- `PLATFORM_POST_URL`: The URL of the platform where content will be posted.
- `POSTING_INTERVAL`: The number of minutes before workflow reruns
- `LOGIN_URL`: The login URL for the platform.
- `EMAIL`: The email address used for login.
- `PASSWORD`: The password used for login.

### Usage

1. Ensure all required environment variables are set.
2. Run the script using the command: `python src/main.py`
3. The script will log in, fetch content, and post it to the platform.

## Getting Started

1. **Clone the Repository**: 
   ```bash
   git clone [your-repo-url]
   cd [your-repo-name]
   ```

2. **Set Up Environment Variables**: 
   - Copy the `.env.sample` file to `.env`:
     ```bash
     cp .env.sample .env
     ```
   - Fill in the necessary details in the `.env` file.

3. **Install Dependencies**: 
   - Install the required Python packages:
     ```bash
     pip install -r requirements.txt
     ```

4. **Run the Application**: 
   - Start the application using the following command:
     ```bash
     python src/main.py
     ```

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting a pull request.

## License

This project is licensed under the MIT License.
