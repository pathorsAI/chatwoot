<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import { TICKET_ATTENTION_CHIPS } from './constants';

const props = defineProps({
  counts: { type: Object, default: () => ({}) },
  activeKeys: { type: Array, default: () => [] },
});

const emit = defineEmits(['toggle']);

const { t } = useI18n();

const chips = computed(() =>
  TICKET_ATTENTION_CHIPS.map(chip => {
    const isActive = props.activeKeys.includes(chip.key);

    return {
      ...chip,
      count: props.counts[chip.key] || 0,
      isActive,
      variant: isActive ? 'faded' : chip.inactiveVariant,
      label: t(`TICKETS.ATTENTION.${chip.i18nKey}`),
      title: t(`TICKETS.ATTENTION.TOOLTIP.${chip.i18nKey}`, {
        count: props.counts[chip.key] || 0,
      }),
    };
  })
);
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <span class="text-sm font-medium text-n-slate-12">
      {{ t('TICKETS.ATTENTION.TITLE') }}
    </span>
    <Button
      v-for="chip in chips"
      :key="chip.key"
      size="sm"
      class="!h-7 !px-2.5"
      :class="{ 'opacity-60': !chip.count && !chip.isActive }"
      :color="chip.color"
      :variant="chip.variant"
      :title="chip.title"
      :data-test-id="`attention-chip-${chip.key}`"
      :aria-pressed="chip.isActive"
      @click="emit('toggle', chip.key)"
    >
      <span class="font-semibold tabular-nums">{{ chip.count }}</span>
      <span class="min-w-0 truncate">{{ chip.label }}</span>
    </Button>
  </div>
</template>
