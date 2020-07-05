/** @noSelfInFile */

export function getLevel(): number;

export function info(tag: string, text: string): void;
export function infof(tag: string, text: string, ...args: unknown[]): void;

export function warn(tag: string, text: string): void;
export function warnf(tag: string, text: string, ...args: unknown[]): void;

export function warning(tag: string, text: string): void;
export function warningf(tag: string, text: string, ...args: unknown[]): void;

export function error(tag: string, text: string): void;
export function errorf(tag: string, text: string, ...args: unknown[]): void;

export function debug(tag: string, text: string): void;
export function debugf(tag: string, text: string, ...args: unknown[]): void;
