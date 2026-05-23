import chalk from 'chalk';

/**
 * Initiates a non-blocking console countdown timeout before automatically proceeding.
 */
export async function handleAutoConfirmTimeout(seconds: number = 10): Promise<void> {
  return new Promise((resolve) => {
    let remaining = seconds;

    const interval = setInterval(() => {
      if (remaining <= 0) {
        clearInterval(interval);
        process.stdout.write('\r\x1b[K');
        resolve();
        return;
      }
      process.stdout.write(
        `\r${chalk.cyan('⏱️  Automatically applying configurations in')} ${chalk.bold.yellow(remaining)} ${chalk.cyan('seconds... Press Ctrl+C to abort.')}`
      );
      remaining--;
    }, 1000);

    process.stdout.write(
      `\r${chalk.cyan('⏱️  Automatically applying configurations in')} ${chalk.bold.yellow(remaining)} ${chalk.cyan('seconds... Press Ctrl+C to abort.')}`
    );
    remaining--;
  });
}
