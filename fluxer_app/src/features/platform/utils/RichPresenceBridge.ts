// SPDX-License-Identifier: AGPL-3.0-or-later

import {normalizeActivities} from '@app/features/presence/state/Activity';
import LocalPresence from '@app/features/presence/state/LocalPresence';
import Presence from '@app/features/presence/state/Presence';
import {getElectronAPI} from '@app/features/ui/utils/NativeUtils';

export function startRichPresenceBridge(): () => void {
	const api = getElectronAPI();
	if (!api?.onRichPresenceActivities) return () => {};
	let unsubscribed = false;
	const apply = (raw: unknown): void => {
		const next = normalizeActivities(raw);
		LocalPresence.setActivities(next);
		Presence.setLocalActivities(next);
	};
	const unsub = api.onRichPresenceActivities(apply);
	void api.getRichPresenceActivities?.()
		.then((raw) => {
			if (unsubscribed) return;
			apply(raw);
		})
		.catch((err) => {
			console.warn('failed to load initial activities', err);
		});
	return () => {
		unsubscribed = true;
		unsub();
		LocalPresence.setActivities([]);
		Presence.setLocalActivities([]);
	};
}
