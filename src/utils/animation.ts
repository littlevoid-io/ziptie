import * as fs from 'node:fs';
import * as path from 'node:path';
import chalk from 'chalk';
import { ListrRenderer } from 'listr2';
import { resolveProjectRoot } from './project.js';
import { VERSION, EMBEDDED_ASSETS } from '../assets.js';

export interface AnimationConfig {
  metadata: { speedMs?: number; width?: number };
  frames: string[][];
}
const defaultAnimation: AnimationConfig = {
  metadata: { speedMs: 150, width: 25 },
  frames: [
    ["   (====)   ", "  ((====))  ", "   ziptie   ", "   v{{VERSION}}  "],
    ["  ((====))  ", " (((====))) ", "   ziptie   ", "   v{{VERSION}}  "],
    [" (((====))) ", "((((====))))", "   ziptie   ", "   v{{VERSION}}  "]
  ]
};
export function loadVersion(): string {
  return VERSION;
}
export function loadConfig(root: string): AnimationConfig {
  const filePath = path.join(root, 'ziptie.animation.json');
  try {
    if (fs.existsSync(filePath)) return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {}
  try {
    const raw = EMBEDDED_ASSETS?.['ziptie.animation.json'];
    if (raw) return JSON.parse(Buffer.from(raw, 'base64').toString('utf8'));
  } catch {}
  return defaultAnimation;
}

export class ColumnRenderer implements ListrRenderer {
  public static nonTTY = false;
  public static rendererOptions = {};
  public static rendererTaskOptions = {};
  public static rendererWithOutput = true;

  private interval: NodeJS.Timeout | null = null;
  private currentFrameIndex = 0;
  private lastLineCount = 0;
  private version = VERSION;
  private animationConfig: AnimationConfig;

  constructor(private tasks: any[], private options: any) {
    const root = resolveProjectRoot();
    this.animationConfig = loadConfig(root);
  }

  public render(): void {
    process.stdout.write('\u001b[?25l');
    this.interval = setInterval(() => {
      this.currentFrameIndex = (this.currentFrameIndex + 1) % this.animationConfig.frames.length;
      this.draw();
    }, this.animationConfig.metadata.speedMs || 150);
    this.subscribeToTasks(this.tasks);
  }

  public end(err?: Error): void {
    if (this.interval) clearInterval(this.interval);
    this.draw();
    process.stdout.write('\u001b[?25h');
  }

  private subscribeToTasks(tasks: any[]): void {
    tasks.forEach(t => {
      t.on('STATE', () => this.draw());
      t.on('OUTPUT', () => this.draw());
      t.on('SUBTASK', (s: any[]) => Array.isArray(s) && this.subscribeToTasks(s));
      if (t.subtasks) this.subscribeToTasks(t.subtasks);
    });
  }

  private draw(): void {
    const tasksOutput: string[] = [];
    this.tasks.forEach(task => this.formatTask(task, tasksOutput));
    const width = this.animationConfig.metadata.width || 25;
    const rightColumn = this.animationConfig.frames[this.currentFrameIndex].map(l => {
      if (!l.includes('{{VERSION}}')) return l;
      const txt = `ziptie v${this.version}`, pad = width - txt.length;
      const L = Math.floor(pad / 2);
      return ' '.repeat(L) + txt + ' '.repeat(pad - L);
    });
    const mergedOutput = this.mergeColumns(tasksOutput, rightColumn);
    if (this.lastLineCount > 0) process.stdout.write(`\u001b[${this.lastLineCount}A`);
    process.stdout.write(mergedOutput.map(l => `\u001b[K${l}`).join('\n') + '\n\u001b[J');
    this.lastLineCount = mergedOutput.length;
  }

  private getIcon(task: any): string {
    if (task.isCompleted()) return chalk.green('√');
    if (task.hasFailed()) return chalk.red('x');
    if (task.isSkipped()) return chalk.yellow('-');
    return task.isPending() ? chalk.cyan('>') : '.';
  }

  private getSubtaskRange(subtasks: any[], remaining: number): { start: number; end: number; showTop: boolean; showBottom: boolean } {
    const N = subtasks.length;
    if (N <= remaining) return { start: 0, end: N - 1, showTop: false, showBottom: false };
    let activeIndex = subtasks.findIndex((s: any) => s.isPending());
    if (activeIndex === -1) activeIndex = subtasks.findIndex((s: any) => !s.isCompleted() && !s.isSkipped());
    activeIndex = Math.max(0, activeIndex === -1 ? N - 1 : activeIndex);
    let start = Math.max(0, activeIndex - 1), end = start + remaining - 1;
    if (start === 0) end = remaining - 2;
    else if (N - start + 1 <= remaining) { end = N - 1; start = N - remaining + 1; }
    else end = start + remaining - 3;
    if (end >= N - 1) { end = N - 1; start = N - remaining + 1; }
    return { start, end, showTop: start > 0, showBottom: end < N - 1 };
  }

  private formatTask(task: any, lines: string[], depth = 0): void {
    lines.push(`${' '.repeat(depth * 2)}${this.getIcon(task)} ${task.title || 'Untitled'}`);
    const active = depth === 0 ? (task.isPending() || task.hasFailed()) : !task.isCompleted();
    if (!task.hasSubtasks() || !active) return;
    const subtasks = task.subtasks;
    if (depth === 0) {
      const remaining = Math.max(3, 15 - this.tasks.length);
      const { start, end, showTop, showBottom } = this.getSubtaskRange(subtasks, remaining);
      if (showTop) lines.push(chalk.dim('  ...'));
      subtasks.forEach((s: any, i: number) => {
        if (i >= start && i <= end) this.formatTask(s, lines, depth + 1);
      });
      if (showBottom) lines.push(chalk.dim('  ...'));
    } else {
      subtasks.forEach((s: any) => this.formatTask(s, lines, depth + 1));
    }
  }

  private mergeColumns(left: string[], right: string[]): string[] {
    const FIXED_HEIGHT = 15, leftLines = [...left];
    while (leftLines.length < FIXED_HEIGHT) leftLines.push('');
    const sliced = leftLines.slice(-FIXED_HEIGHT), result: string[] = [];
    const tIdx = right.findIndex((l) => l.includes('ziptie v') || l.includes('v' + this.version));
    const title = tIdx !== -1 ? right[tIdx] : '';
    const frame = right.filter((_, idx) => idx !== tIdx);
    const startRow = FIXED_HEIGHT - frame.length;
    for (let i = 0; i < FIXED_HEIGHT; i++) {
      const pad = Math.max(50 - sliced[i].replace(/\u001b\[[0-9;]*m/g, '').length, 0);
      const spacer = ' '.repeat(pad) + chalk.cyan('│') + ' ';
      const rightLine = i === 0 ? title : (i >= startRow ? frame[i - startRow] : '');
      result.push(sliced[i] + spacer + chalk.bold.magenta(rightLine));
    }
    return result;
  }
}
