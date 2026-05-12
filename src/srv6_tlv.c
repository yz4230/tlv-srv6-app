#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/in6.h>
#include <linux/ipv6.h>
#include <linux/seg6.h>

#define BPF_NO_GLOBAL_DATA
#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>

#ifndef TLV_TRACE_SUCCESS
#define TLV_TRACE_SUCCESS 1
#endif

#define TLV_RESERVED_LEN 8
#define SRH_MAX_LEN 2048
#define SVC_EMBEDDER 2
#define SVC_SELECTOR 3

struct srh_view {
  struct ipv6hdr *ip6h;
  struct ipv6_sr_hdr *srh;
  __u32 srh_len;
  __u32 tlv_rel;
};

static __always_inline int parse_srh(struct __sk_buff *skb,
                                     struct srh_view *view, __u8 svc) {
  void *data = (void *)(long)skb->data;
  void *data_end = (void *)(long)skb->data_end;
  struct ipv6hdr *ip6h = data;
  struct ipv6_sr_hdr *srh;
  __u32 srh_len;
  __u32 seg_count;
  __u32 tlv_rel;

  if ((void *)(ip6h + 1) > data_end) {
    bpf_printk("tlv_svc=%u: truncated ipv6 header", svc);
    return -1;
  }

  if (ip6h->nexthdr != IPPROTO_ROUTING)
    return 1;

  srh = (struct ipv6_sr_hdr *)(ip6h + 1);
  if ((void *)(srh + 1) > data_end) {
    bpf_printk("tlv_svc=%u: truncated srh", svc);
    return -1;
  }

  if (srh->type != IPV6_SRCRT_TYPE_4) {
    bpf_printk("tlv_svc=%u: unsupported routing type=%u", svc, srh->type);
    return -1;
  }

  srh_len = ((__u32)srh->hdrlen + 1) << 3;
  if (srh_len < sizeof(*srh) || srh_len > SRH_MAX_LEN ||
      (void *)srh + srh_len > data_end) {
    bpf_printk("tlv_svc=%u: invalid srh_len=%u", svc, srh_len);
    return -1;
  }

  seg_count = (__u32)srh->first_segment + 1;
  tlv_rel = sizeof(*srh) + seg_count * sizeof(struct in6_addr);
  if (tlv_rel > srh_len) {
    bpf_printk("tlv_svc=%u: bad segments first=%u srh_len=%u", svc,
               srh->first_segment, srh_len);
    return -1;
  }

  view->ip6h = ip6h;
  view->srh = srh;
  view->srh_len = srh_len;
  view->tlv_rel = tlv_rel;
  return 0;
}

static __always_inline int advance_srh(struct __sk_buff *skb, __u8 decrement,
                                       __u8 svc, __u8 trace_value) {
  struct srh_view view;
  struct in6_addr *segment;
  __u8 next_index;
  int ret;

  ret = parse_srh(skb, &view, svc);
  if (ret != 0)
    return ret > 0 ? BPF_OK : BPF_DROP;

  if (view.srh->segments_left < decrement) {
    bpf_printk("tlv_svc=%u: segments_left=%u decrement=%u drop", svc,
               view.srh->segments_left, decrement);
    return BPF_DROP;
  }

  next_index = view.srh->segments_left - decrement;
  if (next_index > view.srh->first_segment) {
    bpf_printk("tlv_svc=%u: next_index=%u first_segment=%u drop", svc,
               next_index, view.srh->first_segment);
    return BPF_DROP;
  }

  segment = view.srh->segments + next_index;
  if ((void *)(segment + 1) > (void *)(long)skb->data_end) {
    bpf_printk("tlv_svc=%u: truncated segment index=%u", svc, next_index);
    return BPF_DROP;
  }

  view.srh->segments_left = next_index;
  view.ip6h->daddr = *segment;

#if TLV_TRACE_SUCCESS
  if (svc == SVC_EMBEDDER) {
    bpf_printk("tlv_embedder: value=%u decrement=%u next_sl=%u", trace_value,
               decrement, next_index);
  } else if (svc == SVC_SELECTOR) {
    bpf_printk("tlv_selector: value=%u decrement=%u next_sl=%u", trace_value,
               decrement, next_index);
  }
#endif

  return BPF_LWT_REROUTE;
}

static __always_inline int get_reserved_offset(struct __sk_buff *skb,
                                               struct srh_view *view, __u8 svc,
                                               __u32 *offset) {
  void *data = (void *)(long)skb->data;
  void *reserved;

  if (view->srh_len < view->tlv_rel + TLV_RESERVED_LEN) {
    bpf_printk("tlv_svc=%u: missing reserved bytes srh_len=%u tlv_rel=%u",
               svc, view->srh_len, view->tlv_rel);
    return -1;
  }

  reserved = (void *)view->srh + view->tlv_rel;
  if (reserved + TLV_RESERVED_LEN > (void *)(long)skb->data_end) {
    bpf_printk("tlv_svc=%u: truncated reserved bytes", svc);
    return -1;
  }

  *offset = reserved - data;
  return 0;
}

SEC("lwt_xmit/tlv_embedder")
int tlv_embedder(struct __sk_buff *skb) {
  struct srh_view view;
  const __u16 *sid_words;
  __u32 offset;
  __u16 arg_head;
  __u8 value;
  int ret;

  ret = parse_srh(skb, &view, SVC_EMBEDDER);
  if (ret != 0)
    return ret > 0 ? BPF_OK : BPF_DROP;

  if (get_reserved_offset(skb, &view, SVC_EMBEDDER, &offset) < 0)
    return BPF_DROP;

  sid_words = (const __u16 *)view.ip6h->daddr.in6_u.u6_addr16;
  arg_head = bpf_ntohs(sid_words[5]);
  value = arg_head == 0 ? 0 : 1;
  if (bpf_skb_store_bytes(skb, offset, &value, sizeof(value), 0) < 0) {
    bpf_printk("tlv_embedder: failed to write reserved byte");
    return BPF_DROP;
  }

  return advance_srh(skb, 1, SVC_EMBEDDER, value);
}

SEC("lwt_xmit/tlv_selector")
int tlv_selector(struct __sk_buff *skb) {
  __u8 cleanup[TLV_RESERVED_LEN] = {};
  struct srh_view view;
  __u32 offset;
  __u8 value;
  __u8 decrement;
  int ret;

  ret = parse_srh(skb, &view, SVC_SELECTOR);
  if (ret != 0)
    return ret > 0 ? BPF_OK : BPF_DROP;

  if (get_reserved_offset(skb, &view, SVC_SELECTOR, &offset) < 0)
    return BPF_DROP;

  if (bpf_skb_load_bytes(skb, offset, &value, sizeof(value)) < 0) {
    bpf_printk("tlv_selector: failed to read reserved byte");
    return BPF_DROP;
  }
  decrement = value == 0 ? 1 : 2;

  if (bpf_skb_store_bytes(skb, offset, cleanup, sizeof(cleanup), 0) < 0) {
    bpf_printk("tlv_selector: failed to clear reserved bytes");
    return BPF_DROP;
  }

  return advance_srh(skb, decrement, SVC_SELECTOR, value);
}

char _license[] SEC("license") = "GPL";
