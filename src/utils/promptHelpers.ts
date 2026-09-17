import { text, confirm, isCancel } from '@clack/prompts';

export function parseArgsString(raw: string): string[] {
  const trimmed = raw.trim();
  if (!trimmed) return [];
  const matches = trimmed.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g);
  if (!matches) return [];
  return matches.map(arg => arg.replace(/^['"](.*)['"]$/, '$1'));
}

export function validateComputerName(value?: string): string | void {
  if (value?.trim().length === 0) return 'Computer name cannot be empty.';
  if (value !== 'auto' && /[^a-zA-Z0-9-]/.test(value ?? '')) {
    return 'Computer name can only contain alphanumeric characters and hyphens.';
  }
}

export async function promptComputerName(initialValue = 'auto'): Promise<string | null> {
  const result = await text({
    message: 'Computer name:',
    placeholder: initialValue,
    initialValue,
    validate: validateComputerName,
  });
  return isCancel(result) ? null : result;
}

export async function promptTimezone(initialValue = 'auto'): Promise<string | null> {
  const result = await text({
    message: 'System timezone (or "auto"):',
    placeholder: initialValue,
    initialValue,
    validate(value) {
      if (value?.trim().length === 0) return 'Timezone cannot be empty.';
    },
  });
  return isCancel(result) ? null : result;
}

export async function promptUsername(initialValue = 'auto'): Promise<string | null> {
  const result = await text({
    message: 'Auto-login username:',
    placeholder: initialValue,
    initialValue,
    validate(value) {
      if (value?.trim().length === 0) return 'Username cannot be empty.';
    },
  });
  return isCancel(result) ? null : result;
}

export async function promptWorkingDir(initialValue = 'auto'): Promise<string | null> {
  const result = await text({
    message: 'Startup directory:',
    placeholder: initialValue,
    initialValue,
    validate(value) {
      if (value?.trim().length === 0) return 'Working directory cannot be empty.';
    },
  });
  return isCancel(result) ? null : result;
}

export async function promptExecutable(initialValue = 'launch.bat'): Promise<string | null> {
  const result = await text({
    message: 'Startup file name:',
    placeholder: initialValue,
    initialValue,
    validate(value) {
      if (value?.trim().length === 0) return 'Executable name cannot be empty.';
    },
  });
  return isCancel(result) ? null : result;
}

export async function promptArgs(initialValue = ''): Promise<string[] | null> {
  const result = await text({
    message: 'Startup arguments (space-separated, optional):',
    placeholder: initialValue,
    initialValue,
  });
  return isCancel(result) ? null : parseArgsString(result);
}

export async function promptConfirmLaunchBatch(fileName: string): Promise<boolean | null> {
  const result = await confirm({
    message: `Generate starter ${fileName} script in repository?`,
    initialValue: true,
  });
  return isCancel(result) ? null : Boolean(result);
}

export async function promptConfirmConfigUpdate(): Promise<boolean | null> {
  const result = await confirm({
    message: 'Existing ziptie.config.json found. Update configuration?',
    initialValue: true,
  });
  return isCancel(result) ? null : Boolean(result);
}

export interface StartupTaskInputs {
  executable: string;
  args: string[];
  workingDir: string;
}

export async function promptStartupTask(defaults: {
  executable?: string;
  args?: string[];
  workingDir?: string;
}): Promise<StartupTaskInputs | null> {
  const executable = await promptExecutable(defaults.executable || 'launch.bat');
  if (executable === null) return null;
  const args = await promptArgs((defaults.args || []).join(' '));
  if (args === null) return null;
  const workingDir = await promptWorkingDir(defaults.workingDir || 'auto');
  if (workingDir === null) return null;
  return { executable, args, workingDir };
}
