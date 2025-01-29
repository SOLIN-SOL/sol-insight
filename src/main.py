import os
import time
import json
import logging
import tempfile
from typing import Optional
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager
from dotenv import load_dotenv
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException

# Configure logging
logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ContentPoster:
    def __init__(self):
        """Initialize the content poster with environment variables."""
        load_dotenv()

        # Validate required environment variables
        self.required_vars = [
            'GENERATION_ENDPOINT', 
            'PLATFORM_POST_URL', 
            'LOGIN_URL', 
            'EMAIL', 
            'PASSWORD'
        ]
        self._validate_env_vars()

        # Initialize Chrome options with necessary flags for running in cloud environment
        chrome_options = webdriver.ChromeOptions()
        chrome_options.add_argument('--headless')  # Run in headless mode
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-dev-shm-usage')
        chrome_options.add_argument('--disable-gpu')
        chrome_options.add_argument('--disable-extensions')
        chrome_options.add_argument('--disable-software-rasterizer')
        chrome_options.add_argument('--remote-debugging-port=9222')

        # Create a temporary directory for user data
        temp_dir = tempfile.mkdtemp()
        chrome_options.add_argument(f'--user-data-dir={temp_dir}')
        
        try:
            self.driver = webdriver.Chrome(
                service=ChromeService(ChromeDriverManager().install()),
                options=chrome_options
            )
            # Set page load timeout
            self.driver.set_page_load_timeout(30)
            # Set script timeout
            self.driver.set_script_timeout(30)
            # Increase implicit wait time
            self.driver.implicitly_wait(10)
            
        except Exception as e:
            logger.error(f"Failed to initialize Chrome driver: {e}")
            raise

        self.session = requests.Session()
        self.token = None
        self.temp_dir = temp_dir  # Store the temp directory path for cleanup

    def __del__(self):
        """Cleanup method to ensure proper resource handling."""
        try:
            if hasattr(self, 'driver'):
                self.driver.quit()
        except Exception as e:
            logger.error(f"Error while closing driver: {e}")
        
        try:
            if hasattr(self, 'temp_dir') and os.path.exists(self.temp_dir):
                import shutil
                shutil.rmtree(self.temp_dir, ignore_errors=True)
        except Exception as e:
            logger.error(f"Error while removing temporary directory: {e}")

    def _validate_env_vars(self) -> None:
        """Validate that all required environment variables are set."""
        missing_vars = [var for var in self.required_vars if not os.getenv(var)]
        if missing_vars:
            raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

    def find_element_safely(self, by, value, timeout=10):
        """
        Safely find an element with error handling and logging.
        
        Args:
            by: Selenium By locator strategy
            value: Locator value
            timeout: Maximum wait time
        
        Returns:
            WebElement or None
        """
        try:
            element = WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located((by, value))
            )
            return element
        except (TimeoutException, NoSuchElementException) as e:
            logger.error(f"Could not find element {value}: {e}")
            return None

    def login(self) -> bool:
        """
        Log in to the website using Selenium.
        
        Returns:
            bool: True if login is successful, False otherwise
        """
        login_url = os.getenv('LOGIN_URL')

        try:
            self.driver.get(login_url)

            # Locate username input field
            username_input = WebDriverWait(self.driver, 10).until(
                EC.visibility_of_element_located((By.ID, "login-account-name"))
            )

            # Locate password input field
            password_input = WebDriverWait(self.driver, 10).until(
                EC.visibility_of_element_located((By.ID, "login-account-password"))
            )

            # Locate login button
            login_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.ID, "login-button"))
            )

            # Enter username and password
            username_input.send_keys(os.getenv('EMAIL'))
            password_input.send_keys(os.getenv('PASSWORD'))

            # Click the login button
            login_button.click()

            # Check for successful login
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.XPATH, "/html/body/section/div[1]/div[3]/div[2]/div[4]/div[2]/div/div/div/div/div[1]/table/tbody/tr[1]/td[1]/h3/a/div"))
            )

            # Store session cookies
            cookies = self.driver.get_cookies()
            for cookie in cookies:
                self.session.cookies.set(cookie['name'], cookie['value'], domain=cookie['domain'])

            logger.info("Successfully logged in")
            return True

        except Exception as e:
            logger.error(f"Login failed: {e}")
            return False

    def fetch_content(self) -> Optional[str]:
        """Fetch generated content from the specified endpoint."""
        endpoint = os.getenv('GENERATION_ENDPOINT')

        try:
            response = self.session.get(endpoint, timeout=2000)
            response.raise_for_status()

            content = response.text.strip()
            if not content:
                logger.warning("Fetched empty content")
                return None

            logger.info(f"Successfully fetched content (length: {len(content)} chars)")
            logger.info(f"Fetched content: {content}")
            return content

        except requests.RequestException as e:
            logger.error(f"Content fetching failed: {e}")
            return None

    def post_content_to_platform(self, content: str) -> bool:
        """
        Post content to the platform using Selenium.
        """
        if not self.session.cookies:
                logger.error("No session cookies. Please login first.")
                return False

        platform_url = os.getenv('PLATFORM_POST_URL')

        try:
            logger.info("Navigating to platform URL")
            self.driver.get(platform_url)

            new_topic_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.XPATH, "//span[contains(text(), 'New Topic')]"))
            )
            new_topic_button.click()

            title_input = WebDriverWait(self.driver, 10).until(
                EC.visibility_of_element_located((By.XPATH, "//input[@aria-label='What is this discussion about in one brief sentence?']"))
            )

            content_data = json.loads(content)
            logger.info(f"Title to be posted: {content_data['topic']}")
            logger.info(f"Forum post content to be posted: {content_data['forumPost']}")
            title_input.clear()
            title_input.send_keys(content_data['topic'])


            logger.info("Waiting for the category selection dropdown to be visible")
            category_dropdown = WebDriverWait(self.driver, 10).until(
                EC.visibility_of_element_located((By.XPATH, "//*[@id='ember97-header']/div/div/span/span/span/span"))
            )

            # Click the category dropdown
            category_dropdown.click()

            logger.info("Waiting for the sRFC option to be visible")
            sRFC_option = WebDriverWait(self.driver, 10).until(
                EC.visibility_of_element_located((By.XPATH, "//*[@id='ember97-body']/ul/div[1]"))
            )

            # Click the sRFC option
            sRFC_option.click()

            logger.info("Waiting for the body input field to be visible")
            body_input = WebDriverWait(self.driver, 300).until(
                EC.visibility_of_element_located((By.XPATH, "//textarea[@aria-label='Type here. Use Markdown, BBCode, or HTML to format. Drag or paste images.']"))
            )
            logger.info("Entering content into the body input field")
            body_input.clear()
            body_input.send_keys(content_data['forumPost'])

            logger.info("Waiting for the 'Create Topic' button to be clickable")
            create_topic_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.XPATH, "//*[@id='reply-control']/div[3]/div[3]/div[1]/button"))
            )
            logger.info("Clicking the 'Create Topic' button")
            create_topic_button.click()

            # logger.info("Checking for successful posting")
            # WebDriverWait(self.driver, 10).until(
            #     EC.presence_of_element_located((By.XPATH, "//div[contains(text(), 'Topic created successfully')]"))
            # )

            logger.info("Content posted to the platform successfully")
            return True

        except Exception as e:
            logger.error(f"Content posting to the platform failed: {e}", exc_info=True)
            logger.debug(f"Content attempted to post: {content}")
            return False

    def run(self) -> bool:
        """Execute the full content posting workflow."""
        # Attempt login
        if not self.login():
            return False

        # Fetch content
        content = self.fetch_content()
        if not content:
            return False

        # Post content to the platform
        if not self.post_content_to_platform(content):
            return False

        return True

def main():
    """Main entry point for the script."""
    poster = ContentPoster()
    posting_interval = os.getenv('POSTING_INTERVAL')

    if posting_interval:
        posting_interval = int(posting_interval)

        while True:
            try:
                success = poster.run()
                if success:
                    logger.info("Content posting workflow completed successfully")
                else:
                    logger.error("Content posting workflow failed")
            except Exception as e:
                logger.error(f"Unexpected error: {e}")

            # Wait for the specified interval before running the workflow again
            logger.info(f"Waiting for {posting_interval} hours...")
            time.sleep(posting_interval * 60 * 60)
    else:
        # Run the workflow once if the POSTING_INTERVAL environment variable is not set
        try:
            success = poster.run()
            if success:
                logger.info("Content posting workflow completed successfully")
            else:
                logger.error("Content posting workflow failed")
        except Exception as e:
            logger.error(f"Unexpected error: {e}")

        exit(0)


if __name__ == "__main__":
    main()
