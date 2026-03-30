/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Copyright (C) 2015-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

#ifndef _WG_DEVICE_H
#define _WG_DEVICE_H

#include "noise.h"
#include "allowedips.h"
#include "peerlookup.h"
#include "cookie.h"

#include <linux/types.h>
#include <linux/netdevice.h>
#include <linux/workqueue.h>
#include <linux/mutex.h>
#include <linux/net.h>
#include <linux/ptr_ring.h>
#include <crypto/aead.h>

struct wg_device;

struct multicore_worker {
	void *ptr;
	struct work_struct work;
};

struct crypt_queue {
	struct ptr_ring ring;
	struct multicore_worker __percpu *worker;
	int last_cpu;
};

struct prev_queue {
	struct sk_buff *head, *tail, *peeked;
	struct { struct sk_buff *next, *prev; } empty; // Match first 2 members of struct sk_buff.
	atomic_t count;
};

/*
 * Per-CPU AES-GCM state.
 *
 * req – a single pre-allocated aead_request buffer, sized at device-init
 *       time using crypto_aead_reqsize() on a probe transform.  On the data
 *       path we call aead_request_set_tfm() to point it at the current
 *       keypair's per-keypair crypto_aead handle, then encrypt/decrypt.
 *       This eliminates both crypto_aead_setkey() *and* aead_request_alloc()
 *       from the per-packet hot path.
 *
 * Each CPU owns its own copy so the fast path never takes a lock.
 */
struct wg_aes_percpu {
	struct aead_request *req;
};

struct wg_device {
	struct net_device *dev;
	struct crypt_queue encrypt_queue, decrypt_queue;
	struct sock __rcu *sock4, *sock6;
	struct net __rcu *creating_net;
	struct noise_static_identity static_identity;
	struct workqueue_struct *handshake_receive_wq, *handshake_send_wq;
	struct workqueue_struct *packet_crypt_wq;
	struct sk_buff_head incoming_handshakes;
	int incoming_handshake_cpu;
	struct multicore_worker __percpu *incoming_handshakes_worker;
	struct cookie_checker cookie_checker;
	struct pubkey_hashtable *peer_hashtable;
	struct index_hashtable *index_hashtable;
	struct allowedips peer_allowedips;
	struct mutex device_update_lock, socket_update_lock;
	struct list_head device_list, peer_list;
	unsigned int num_peers, device_update_gen;
	u32 fwmark;
	u16 incoming_port;
	struct wg_aes_percpu __percpu *aes_cpu; /* NULL when is_chacha */
	bool is_chacha;
};

int wg_device_init(void);
void wg_device_uninit(void);

#endif /* _WG_DEVICE_H */
