# Event Bus - Pub/Sub pattern implementation
# Allows decoupled communication between components

class EventBus {
    hidden [hashtable]$subscribers = @{}
    hidden [ILogger]$logger

    EventBus([ILogger]$logger) {
        $this.logger = $logger
    }

    # Subscribe to an event
    [void] Subscribe([string]$eventType, [ScriptBlock]$handler) {
        if (-not $this.subscribers.ContainsKey($eventType)) {
            $this.subscribers[$eventType] = @()
        }
        $this.subscribers[$eventType] += $handler
        $this.logger.Debug("Subscriber added for event: $eventType")
    }

    # Unsubscribe from an event
    [void] Unsubscribe([string]$eventType, [ScriptBlock]$handler) {
        if ($this.subscribers.ContainsKey($eventType)) {
            $this.subscribers[$eventType] = $this.subscribers[$eventType] | Where-Object { $_ -ne $handler }
        }
    }

    # Publish an event
    [void] Publish([string]$eventType, [object]$eventData) {
        $this.logger.Info("Event published: $eventType", @{ Data = $eventData })

        if ($this.subscribers.ContainsKey($eventType)) {
            foreach ($handler in $this.subscribers[$eventType]) {
                try {
                    & $handler $eventData
                } catch {
                    $this.logger.Error("Error in event handler for $eventType", @{
                        Error = $_.Exception.Message
                        Stack = $_.ScriptStackTrace
                    })
                }
            }
        }
    }

    # Publish async (fire and forget)
    [void] PublishAsync([string]$eventType, [object]$eventData) {
        Start-Job -ScriptBlock {
            param($bus, $type, $data)
            $bus.Publish($type, $data)
        } -ArgumentList $this, $eventType, $eventData | Out-Null
    }

    # Get subscriber count for event
    [int] GetSubscriberCount([string]$eventType) {
        if ($this.subscribers.ContainsKey($eventType)) {
            return $this.subscribers[$eventType].Count
        }
        return 0
    }

    # Clear all subscribers
    [void] ClearAll() {
        $this.subscribers.Clear()
        $this.logger.Info("All event subscribers cleared")
    }
}

# Event definitions
class ProfileChangedEvent {
    [string]$OldProfile
    [string]$NewProfile
    [DateTime]$Timestamp
    [string]$User
    [bool]$AppliedDynamically

    ProfileChangedEvent([string]$old, [string]$new, [bool]$dynamic) {
        $this.OldProfile = $old
        $this.NewProfile = $new
        $this.Timestamp = Get-Date
        $this.User = $env:USERNAME
        $this.AppliedDynamically = $dynamic
    }
}

class SystemResourcesChangedEvent {
    [SystemResources]$NewResources
    [hashtable]$Delta
    [DateTime]$Timestamp

    SystemResourcesChangedEvent([SystemResources]$resources, [hashtable]$delta) {
        $this.NewResources = $resources
        $this.Delta = $delta
        $this.Timestamp = Get-Date
    }
}

class MemoryThresholdExceededEvent {
    [int]$CurrentUsagePercent
    [int]$Threshold
    [string]$ProfileName
    [DateTime]$Timestamp

    MemoryThresholdExceededEvent([int]$usage, [int]$threshold, [string]$profile) {
        $this.CurrentUsagePercent = $usage
        $this.Threshold = $threshold
        $this.ProfileName = $profile
        $this.Timestamp = Get-Date
    }
}
