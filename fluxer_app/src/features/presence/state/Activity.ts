// SPDX-License-Identifier: AGPL-3.0-or-later

export const ActivityTypes = {
	PLAYING: 0,
	LISTENING: 2,
	WATCHING: 3,
} as const;

export interface Activity {
	name: string;
	type: number;
	details?: string;
	state?: string;
	timestamps?: {
		start?: number;
		end?: number;
	};
}

const MAX_ACTIVITIES = 5;
const MAX_TEXT = 128;
const EMPTY: ReadonlyArray<Activity> = [];

export function emptyActivities(): ReadonlyArray<Activity> {
	return EMPTY;
}

export function activitiesKey(list: ReadonlyArray<Activity> | null | undefined): string {
	if (!list?.length) return '';
	return list
		.map((activity) => {
			const start = activity.timestamps?.start ?? '';
			const end = activity.timestamps?.end ?? '';
			return `${activity.type}|${activity.name}|${activity.details ?? ''}|${activity.state ?? ''}|${start}|${end}`;
		})
		.join('\n');
}

export function normalizeActivities(raw: unknown): Array<Activity> {
	if (!Array.isArray(raw)) return [];
	const out: Array<Activity> = [];
	for (const item of raw) {
		if (out.length >= MAX_ACTIVITIES) break;
		const activity = normalizeActivity(item);
		if (activity) out.push(activity);
	}
	return out;
}

function normalizeActivity(raw: unknown): Activity | null {
	if (!raw || typeof raw !== 'object') return null;
	const record = raw as Record<string, unknown>;
	const name = clipText(record.name);
	if (!name) return null;
	const activity: Activity = {name, type: activityType(record.type)};
	const details = clipText(record.details);
	const state = clipText(record.state);
	if (details) activity.details = details;
	if (state) activity.state = state;
	const timestamps = normalizeTimestamps(record.timestamps);
	if (timestamps) activity.timestamps = timestamps;
	return activity;
}

function activityType(raw: unknown): number {
	if (raw === ActivityTypes.LISTENING || raw === ActivityTypes.WATCHING) return raw;
	return ActivityTypes.PLAYING;
}

function clipText(raw: unknown): string | null {
	if (typeof raw !== 'string') return null;
	const text = raw.trim();
	if (!text || text.length > MAX_TEXT) return null;
	return text;
}

function normalizeTimestamps(raw: unknown): Activity['timestamps'] | null {
	if (!raw || typeof raw !== 'object') return null;
	const record = raw as Record<string, unknown>;
	const start = timestamp(record.start);
	const end = timestamp(record.end);
	if (start == null && end == null) return null;
	return {
		...(start != null ? {start} : {}),
		...(end != null ? {end} : {}),
	};
}

function timestamp(raw: unknown): number | null {
	if (typeof raw !== 'number' || !Number.isFinite(raw) || raw <= 0 || raw >= 10_000_000_000_000) return null;
	return Math.trunc(raw);
}
