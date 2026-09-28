// SPDX-License-Identifier: AGPL-3.0-or-later

import {type Activity, ActivityTypes} from '@app/features/presence/state/Activity';
import Presence from '@app/features/presence/state/Presence';
import styles from '@app/features/user/components/profile/ActivitySection.module.css';
import {msg} from '@lingui/core/macro';
import {useLingui} from '@lingui/react/macro';
import {GameControllerIcon, MonitorPlayIcon, SpeakerHighIcon} from '@phosphor-icons/react';
import {observer} from 'mobx-react-lite';
import type React from 'react';

const PLAYING_DESCRIPTOR = msg({
	message: 'Playing',
	comment: 'Label above a game name on a user profile',
});
const LISTENING_DESCRIPTOR = msg({
	message: 'Listening to',
	comment: 'Label above a music app name on a user profile',
});
const WATCHING_DESCRIPTOR = msg({
	message: 'Watching',
	comment: 'Label above a video app name on a user profile',
});

function labelFor(type: number): typeof PLAYING_DESCRIPTOR {
	if (type === ActivityTypes.LISTENING) return LISTENING_DESCRIPTOR;
	if (type === ActivityTypes.WATCHING) return WATCHING_DESCRIPTOR;
	return PLAYING_DESCRIPTOR;
}

function ActivityIcon({type}: {type: number}): React.ReactElement {
	if (type === ActivityTypes.LISTENING) {
		return <SpeakerHighIcon className={styles.icon} weight="fill" />;
	}
	if (type === ActivityTypes.WATCHING) {
		return <MonitorPlayIcon className={styles.icon} weight="fill" />;
	}
	return <GameControllerIcon className={styles.icon} weight="fill" />;
}

interface ActivitySectionProps {
	userId: string;
	'data-flx'?: string;
}

export const ActivitySection: React.FC<ActivitySectionProps> = observer(({userId, 'data-flx': flx}) => {
	const {i18n} = useLingui();
	const activities = Presence.getActivities(userId);
	if (activities.length === 0) return null;
	return (
		<div className={styles.section} data-flx={flx ?? 'user.profile.activity-section.section'}>
			{activities.map((activity, idx) => (
				<ActivityCard
					key={`${activity.type}:${activity.name}:${idx}`}
					activity={activity}
					label={i18n._(labelFor(activity.type))}
				/>
			))}
		</div>
	);
});

function ActivityCard({activity, label}: {activity: Activity; label: string}): React.ReactElement {
	return (
		<div className={styles.card} data-flx="user.profile.activity-section.card">
			<div className={styles.header}>
				<ActivityIcon type={activity.type} />
				<span className={styles.label}>{label}</span>
			</div>
			<div className={styles.name}>{activity.name}</div>
			{activity.details ? <div className={styles.line}>{activity.details}</div> : null}
			{activity.state ? <div className={styles.line}>{activity.state}</div> : null}
		</div>
	);
}
