/*
 * arch/arm/mach-msm/msm_mpdecision.h
 *
 * Copyright (c) 2012-2013, Dennis Rassmann <showp1984@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#ifndef __MSM_MPDEC_H__
#define __MSM_MPDEC_H__

#include <asm-generic/cputime.h>
#include <linux/mutex.h>

#define MPDEC_TAG				"[MPDEC]: "
#define MSM_MPDEC_STARTDELAY			20000
#define MSM_MPDEC_DELAY				130
#define MSM_MPDEC_PAUSE				10000

#ifdef CONFIG_ARCH_MSM8974
#define MSM_MPDEC_IDLE_FREQ			499200
#elif defined CONFIG_ARCH_MSM8X60 || defined CONFIG_ARCH_MSM8960 || defined CONFIG_ARCH_MSM8930
#define MSM_MPDEC_IDLE_FREQ			486000
#else
#define MSM_MPDEC_IDLE_FREQ			486000
#endif

#ifdef CONFIG_MSM_MPDEC_INPUTBOOST_CPUMIN
#define MSM_MPDEC_BOOSTTIME			1000
#ifdef CONFIG_ARCH_MSM8974
#define MSM_MPDEC_BOOSTFREQ_CPU0		960000
#define MSM_MPDEC_BOOSTFREQ_CPU1		960000
#define MSM_MPDEC_BOOSTFREQ_CPU2		729600
#define MSM_MPDEC_BOOSTFREQ_CPU3		576000
#elif defined CONFIG_ARCH_MSM8X60 || defined CONFIG_ARCH_MSM8960 || defined CONFIG_ARCH_MSM8930
#define MSM_MPDEC_BOOSTFREQ_CPU0		918000
#define MSM_MPDEC_BOOSTFREQ_CPU1		918000
#define MSM_MPDEC_BOOSTFREQ_CPU2		702000
#define MSM_MPDEC_BOOSTFREQ_CPU3		594000
#else
#define MSM_MPDEC_BOOSTFREQ_CPU0		918000
#define MSM_MPDEC_BOOSTFREQ_CPU1		918000
#define MSM_MPDEC_BOOSTFREQ_CPU2		702000
#define MSM_MPDEC_BOOSTFREQ_CPU3		594000
#endif
#endif

enum {
	MSM_MPDEC_DISABLED = 0,
	MSM_MPDEC_IDLE,
	MSM_MPDEC_DOWN,
	MSM_MPDEC_UP,
};

struct msm_mpdec_cpudata_t {
	struct mutex hotplug_mutex;
	int online;
	cputime64_t on_time;
	cputime64_t on_time_total;
	long long unsigned int times_cpu_hotplugged;
	long long unsigned int times_cpu_unplugged;
#ifdef CONFIG_MSM_MPDEC_INPUTBOOST_CPUMIN
	struct mutex boost_mutex;
	struct mutex unboost_mutex;
	unsigned long int norm_min_freq;
	unsigned long int boost_freq;
	cputime64_t boost_until;
	bool is_boosted;
	bool revib_wq_running;
#endif
};
#endif //__MSM_MPDEC_H__

