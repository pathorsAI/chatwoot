<script setup>
import { computed } from 'vue';

const props = defineProps({
  count: { type: [Number, String], default: 0 },
  tone: { type: String, default: 'neutral' },
  title: { type: String, default: '' },
});

// Colour carries meaning, not decoration: `attention` is work nobody has picked
// up, `danger` is work that is already late, `muted` is context rather than a
// call to action. `neutral` stays the plain unread pill.
const TONE_CLASSES = {
  neutral: 'bg-n-slate-4 text-n-slate-12 dark:bg-n-slate-5',
  attention: 'bg-n-brand text-white',
  danger: 'bg-n-ruby-9 text-white',
  muted: 'text-n-slate-10',
};

const normalizedCount = computed(() => {
  const count = Number(props.count);
  return Number.isFinite(count) && count > 0 ? count : 0;
});

const displayCount = computed(() =>
  normalizedCount.value > 99 ? '99+' : String(normalizedCount.value)
);

const toneClass = computed(
  () => TONE_CLASSES[props.tone] ?? TONE_CLASSES.neutral
);
</script>

<template>
  <span
    v-if="normalizedCount > 0"
    data-test-id="sidebar-unread-badge"
    :data-tone="tone"
    :title="title || undefined"
    class="inline-grid h-5 min-w-5 place-items-center rounded-full px-1 text-xxs font-medium leading-3 flex-shrink-0"
    :class="toneClass"
  >
    {{ displayCount }}
  </span>
  <span v-else class="hidden" />
</template>
