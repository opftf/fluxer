// SPDX-License-Identifier: AGPL-3.0-or-later

import type {Activity} from '@app/features/presence/state/Activity';
import type {GatewayCustomStatusPayload} from '@app/features/user/state/CustomStatus';
import type {UserPartial} from '@fluxer/schema/src/domains/user/UserResponseSchemas';

export interface PresenceRecord {
	readonly guild_id?: string | null;
	readonly user: UserPartial;
	readonly status?: string | null;
	readonly afk?: boolean;
	readonly mobile?: boolean;
	readonly custom_status?: GatewayCustomStatusPayload | null;
	readonly activities?: ReadonlyArray<Activity> | null;
}

export type Presence = PresenceRecord;
