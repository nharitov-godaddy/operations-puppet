# SPDX-License-Identifier: Apache-2.0
# dlq_transformer.rb
# Logstash Ruby script transform a dead letter queue event into the expected format
# @version: 1.0.2

def register(params) end

def filter(event)
  # Make a copy
  original_event = event.to_hash

  # Logstash has a feature to prevent a resubmit loop of dead letter events:
  # https://www.elastic.co/guide/en/logstash/current/dead-letter-queues.html#processing-dlq-events
  # However, it is unknown whether this mechanism will trigger if an event of a dead letter
  # generated by this script is encountered.
  #
  # If the type field of the original event is "dlq", drop it in an attempt to short-circuit a possible
  # dead letter recursion situation.
  if original_event['type'] == 'dlq'
    event.cancel
    return [event]
  end

  # Remove all original keys, except special ones
  original_event.each_key do | k |
    next if k[0] == '@'
    event.remove(k)
  end

  # Rebuild the event in the new format
  event.set('type', 'dlq')
  event.set('plugin_type', event.get('[@metadata][dead_letter_queue][plugin_type]'))
  event.set('message', event.get('[@metadata][dead_letter_queue][reason]'))
  event.set('plugin_id', event.get('[@metadata][dead_letter_queue][plugin_id]'))
  event.set('original', original_event.to_json)
  [event]
end
